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

    metrics = CactusPipelineMetrics.new(account: @account).call

    assert_equal @account, metrics.account
    assert_includes metrics.workflow_counts.keys, "needs_review"
    assert_operator metrics.workflow_counts["needs_review"], :>=, 1
    assert_operator metrics.gate_counts[:gate_one_complete], :>=, 1
    assert_operator metrics.gate_counts[:gate_two_complete], :>=, 1
    assert_operator metrics.training_counts["approved"], :>=, 1
    assert_operator metrics.training_review_rate, :>=, 1
    assert_operator metrics.code_link_counts[:commits], :>=, 1
    assert_operator metrics.github_linkage_rate, :>=, 1
    assert_operator metrics.domain_counts["ui"], :>=, 1
    assert_operator metrics.legacy_counts[:needs_structuring], :>=, 1
    assert_equal false, metrics.ai_acceptance_tracking_available
  end
end
