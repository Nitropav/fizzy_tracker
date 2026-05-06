require "test_helper"

class CactusPipelineMetricsTest < ActiveSupport::TestCase
  setup do
    @account = accounts("37s")
  end

  test "returns account-scoped pipeline metrics" do
    cards(:layout).create_resolution_record!(
      legacy_import: true,
      legacy_source: "asana",
      legacy_external_id: "dashboard-legacy",
      legacy_imported_at: Time.current,
      legacy_metadata: { "completed" => false },
      needs_structuring: true
    )

    cards(:text).create_resolution_record!(
      problem_description: "Text is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Text should be readable",
      actual_behavior: "Text is too small",
      environment_context: "Card detail page",
      root_cause: "Wrong font scale",
      fix_summary: "Adjusted the font scale",
      verification_steps: "Opened the card and confirmed the text is readable",
      domain: "ui"
    )
    cards(:text).code_links.create!(
      account: @account,
      provider: "github",
      external_type: "commit",
      external_id: "abc123",
      sha: "abc123",
      title: "Fix CT-3"
    )

    training_example = TrainingExamples::Generator.new(cards(:text)).generate
    training_example.approve!(reviewer: users(:kevin))
    training_export = TrainingExampleExport.create!(
      account: @account,
      user: users(:kevin),
      status: :completed,
      filename: "training-examples.jsonl",
      example_count: 1,
      training_example_ids: [ training_example.id ],
      completed_at: Time.current
    )
    training_example.mark_exported!(training_example_export: training_export)

    Github::WebhookDelivery.create!(
      account: @account,
      delivery_id: "dashboard-delivery-1",
      event: "push",
      payload_sha256: "abc",
      status: "processed",
      linked_code_references_count: 1,
      processed_at: Time.current
    )
    Github::WebhookDelivery.create!(
      account: @account,
      delivery_id: "dashboard-delivery-2",
      event: "push",
      payload_sha256: "def",
      status: "failed",
      error_message: "Invalid payload",
      processed_at: Time.current
    )

    applied_run = cards(:text).ai_runs.create!(
      user: users(:kevin),
      run_type: "resolution_draft",
      input_context: {},
      output: { "status" => "suggested" },
      metadata: {}
    )
    applied_run.complete!(output: { "status" => "suggested" })
    applied_run.mark_applied!(user: users(:kevin))

    dismissed_run = cards(:text).ai_runs.create!(
      user: users(:kevin),
      run_type: "duplicate_issue_suggestion",
      input_context: {},
      output: { "status" => "candidates_found" },
      metadata: {}
    )
    dismissed_run.complete!(output: { "status" => "candidates_found" })
    dismissed_run.dismiss!(user: users(:kevin))

    metrics = CactusPipelineMetrics.new(account: @account, period: "7").call

    assert_equal @account, metrics.account
    assert_equal "7", metrics.period
    assert_equal "Last 7 days", metrics.period_label
    assert_equal 7, metrics.trend_points.size
    assert_includes metrics.workflow_counts.keys, "needs_review"
    assert_operator metrics.workflow_counts["needs_review"], :>=, 1
    assert_operator metrics.gate_counts[:gate_one_complete], :>=, 1
    assert_operator metrics.gate_counts[:gate_two_complete], :>=, 1
    assert_operator metrics.gate_completion_rates[:gate_one], :>=, 1
    assert_operator metrics.gate_completion_rates[:gate_two], :>=, 1
    assert_operator metrics.backlog_health[:active_total], :>=, 1
    assert_operator metrics.training_counts["exported"], :>=, 1
    assert_operator metrics.training_review_rate, :>=, 1
    assert_operator metrics.training_export_metrics[:export_batches], :>=, 1
    assert_operator metrics.training_export_metrics[:exported_examples], :>=, 1
    assert_operator metrics.training_export_metrics[:export_rate], :>=, 1
    assert_equal "training-examples.jsonl", metrics.training_export_metrics[:recent_exports].first[:filename]
    assert_operator metrics.code_link_counts[:commits], :>=, 1
    assert_operator metrics.github_linkage_rate, :>=, 1
    assert_operator metrics.github_webhook_metrics[:processed], :>=, 1
    assert_operator metrics.github_webhook_metrics[:failed], :>=, 1
    assert_operator metrics.github_webhook_metrics[:failure_rate], :>=, 1
    assert_operator metrics.github_webhook_metrics[:linked_code_references], :>=, 1
    assert_operator metrics.domain_counts["ui"], :>=, 1
    assert_operator metrics.legacy_counts[:needs_structuring], :>=, 1
    assert_operator metrics.ai_suggestion_metrics[:applied], :>=, 1
    assert_operator metrics.ai_suggestion_metrics[:dismissed], :>=, 1
    assert_operator metrics.ai_suggestion_metrics[:acceptance_rate], :>=, 1
    assert_operator metrics.operational_alerts.size, :>=, 1
    assert_operator metrics.trend_totals[:gate_one_completed], :>=, 1
    assert_operator metrics.trend_totals[:gate_two_completed], :>=, 1
    assert_operator metrics.trend_totals[:training_examples_created], :>=, 1
    assert_operator metrics.trend_totals[:training_examples_exported], :>=, 1
    assert_operator metrics.trend_totals[:github_webhook_failures], :>=, 1
    assert_operator metrics.trend_totals[:ai_suggestions_completed], :>=, 1
    assert_operator metrics.max_trend_value, :>=, 1
  end

  test "falls back to default activity period" do
    metrics = CactusPipelineMetrics.new(account: @account, period: "invalid").call

    assert_equal CactusPipelineMetrics::DEFAULT_PERIOD, metrics.period
    assert_equal CactusPipelineMetrics::PERIOD_OPTIONS.fetch(CactusPipelineMetrics::DEFAULT_PERIOD), metrics.period_label
    assert_equal CactusPipelineMetrics::DEFAULT_PERIOD.to_i, metrics.trend_points.size
  end
end
