class CactusPipelineMetrics
  PERIOD_OPTIONS = {
    "7" => "Last 7 days",
    "30" => "Last 30 days",
    "90" => "Last 90 days"
  }.freeze
  DEFAULT_PERIOD = "30"
  TREND_KEYS = %i[
    created_issues
    gate_one_completed
    gate_two_completed
    training_examples_created
    training_examples_exported
    github_webhook_failures
    ai_suggestions_completed
  ].freeze

  Result = Data.define(
    :account,
    :generated_at,
    :period,
    :period_label,
    :period_options,
    :period_started_at,
    :period_ended_at,
    :workflow_counts,
    :gate_counts,
    :missing_gate_one_counts,
    :missing_gate_two_counts,
    :gate_completion_rates,
    :backlog_health,
    :training_counts,
    :training_review_rate,
    :training_export_metrics,
    :domain_counts,
    :code_link_counts,
    :github_linkage_rate,
    :github_webhook_metrics,
    :ai_run_counts,
    :ai_suggestion_metrics,
    :legacy_counts,
    :operational_alerts,
    :trend_points,
    :trend_totals,
    :max_trend_value
  )

  def initialize(account:, period: DEFAULT_PERIOD)
    @account = account
    @period = normalize_period(period)
  end

  def call
    Result.new(
      account: account,
      generated_at: generated_at,
      period: period,
      period_label: PERIOD_OPTIONS.fetch(period),
      period_options: PERIOD_OPTIONS,
      period_started_at: period_started_at,
      period_ended_at: period_ended_at,
      workflow_counts: workflow_counts,
      gate_counts: gate_counts,
      missing_gate_one_counts: missing_gate_counts(Card::ResolutionRecord::GATE_ONE_REQUIRED_FIELDS),
      missing_gate_two_counts: missing_gate_counts(Card::ResolutionRecord::GATE_TWO_REQUIRED_FIELDS),
      gate_completion_rates: gate_completion_rates,
      backlog_health: backlog_health,
      training_counts: training_counts,
      training_review_rate: training_review_rate,
      training_export_metrics: training_export_metrics,
      domain_counts: domain_counts,
      code_link_counts: code_link_counts,
      github_linkage_rate: github_linkage_rate,
      github_webhook_metrics: github_webhook_metrics,
      ai_run_counts: ai_run_counts,
      ai_suggestion_metrics: ai_suggestion_metrics,
      legacy_counts: legacy_counts,
      operational_alerts: operational_alerts,
      trend_points: trend_points,
      trend_totals: trend_totals,
      max_trend_value: max_trend_value
    )
  end

  private
    attr_reader :account, :period

    def normalize_period(value)
      PERIOD_OPTIONS.key?(value.to_s) ? value.to_s : DEFAULT_PERIOD
    end

    def generated_at
      @generated_at ||= Time.current
    end

    def period_days
      period.to_i
    end

    def period_started_at
      @period_started_at ||= (generated_at.to_date - (period_days - 1)).beginning_of_day
    end

    def period_ended_at
      generated_at
    end

    def trend_dates
      @trend_dates ||= (period_started_at.to_date..period_ended_at.to_date).to_a
    end

    def cards
      account.cards
    end

    def resolution_records
      Card::ResolutionRecord.where(account: account)
    end

    def training_examples
      account.training_examples
    end

    def training_example_exports
      account.training_example_exports
    end

    def github_webhook_deliveries
      account.github_webhook_deliveries
    end

    def workflow_counts
      @workflow_counts ||= begin
        query = Cards::CactusWorkflowQuery.new(cards)

        Card::CactusWorkflow::CACTUS_WORKFLOW_STATES.index_with do |state|
          query.for(state).count
        end
      end
    end

    def gate_counts
      @gate_counts ||= {
        total_records: resolution_records.count,
        gate_one_complete: resolution_records.gate_one_status_complete.count,
        gate_one_incomplete: resolution_records.gate_one_status_incomplete.count,
        gate_two_complete: resolution_records.gate_two_status_complete.count,
        gate_two_incomplete: resolution_records.gate_two_status_incomplete.count
      }
    end

    def gate_completion_rates
      @gate_completion_rates ||= {
        gate_one: percentage(gate_counts[:gate_one_complete], gate_counts[:total_records]),
        gate_two: percentage(gate_counts[:gate_two_complete], gate_counts[:total_records])
      }
    end

    def backlog_health
      @backlog_health ||= begin
        active_states = %w[ needs_info open in_progress needs_review ]
        active_counts = workflow_counts.slice(*active_states)
        total_active = active_counts.values.sum
        bottleneck = active_counts.max_by { |_state, count| count }

        {
          active_total: total_active,
          needs_info: workflow_counts["needs_info"],
          untriaged_open: workflow_counts["open"],
          in_progress: workflow_counts["in_progress"],
          needs_review: workflow_counts["needs_review"],
          resolved_pending_training_review: workflow_counts["resolved"],
          closed_training_done: workflow_counts["closed"],
          bottleneck_state: bottleneck&.first,
          bottleneck_count: bottleneck&.last || 0,
          ready_for_developer: workflow_counts["open"],
          ready_for_resolution: workflow_counts["needs_review"]
        }
      end
    end

    def missing_gate_counts(fields)
      fields.index_with do |field|
        resolution_records.where(field => [ nil, "" ]).count
      end
    end

    def training_counts
      @training_counts ||= TrainingExample::STATUSES.index_with do |status|
        training_examples.where(status: status).count
      end
    end

    def training_review_rate
      reviewed = training_examples.where(status: %w[ approved rejected exported ]).count
      percentage(reviewed, training_examples.count)
    end

    def training_export_metrics
      @training_export_metrics ||= begin
        exported_examples = training_examples.exported.count
        approved_ready = training_examples.approved.count
        total_reviewed_or_exported = training_examples.where(status: %w[ approved rejected exported ]).count
        latest_export = training_example_exports.latest_first.first

        {
          approved_ready: approved_ready,
          exported_examples: exported_examples,
          export_batches: training_example_exports.completed.count,
          failed_exports: training_example_exports.failed.count,
          export_rate: percentage(exported_examples, total_reviewed_or_exported),
          last_exported_at: latest_export&.completed_at,
          recent_exports: training_example_exports.latest_first.limit(3).map { export_payload(it) }
        }
      end
    end

    def domain_counts
      resolution_records.where.not(domain: [ nil, "" ]).group(:domain).order(Arel.sql("COUNT(*) DESC")).limit(10).count
    end

    def code_link_counts
      {
        total: account.card_code_links.count,
        commits: account.card_code_links.commits.count,
        pull_requests: account.card_code_links.pull_requests.count,
        linked_cards: account.card_code_links.distinct.count(:card_id)
      }
    end

    def github_linkage_rate
      gate_two_cards = cards.joins(:resolution_record)
        .where(card_resolution_records: { gate_two_status: "complete" })
        .distinct
      linked_gate_two_cards = gate_two_cards.joins(:code_links).distinct.count

      percentage(linked_gate_two_cards, gate_two_cards.count)
    end

    def github_webhook_metrics
      @github_webhook_metrics ||= begin
        counts = Github::WebhookDelivery::STATUSES.index_with do |status|
          github_webhook_deliveries.where(status: status).count
        end
        total = github_webhook_deliveries.count
        failed = counts["failed"]
        processed = counts["processed"]

        {
          total: total,
          processed: processed,
          failed: failed,
          pending: counts["pending"],
          processing: counts["processing"],
          failure_rate: percentage(failed, total),
          processed_rate: percentage(processed, total),
          linked_code_references: github_webhook_deliveries.sum(:linked_code_references_count),
          last_delivery_at: github_webhook_deliveries.maximum(:created_at),
          last_processed_at: github_webhook_deliveries.where.not(processed_at: nil).maximum(:processed_at)
        }
      end
    end

    def ai_run_counts
      @ai_run_counts ||= AiRun::STATUSES.index_with do |status|
        account.ai_runs.where(status: status).count
      end
    end

    def ai_suggestion_metrics
      @ai_suggestion_metrics ||= begin
        runs = account.ai_runs.completed.where(run_type: AiRun::DISMISSIBLE_RUN_TYPES).to_a
        active = runs.count(&:active_suggestion?)
        applied = runs.count(&:applied?)
        dismissed = runs.count(&:dismissed?)

        {
          total: runs.size,
          active: active,
          applied: applied,
          dismissed: dismissed,
          acceptance_rate: percentage(applied, applied + dismissed),
          dismissal_rate: percentage(dismissed, applied + dismissed),
          by_type: AiRun::DISMISSIBLE_RUN_TYPES.index_with { |run_type| runs.count { it.run_type == run_type } }
        }
      end
    end

    def legacy_counts
      legacy = resolution_records.where(legacy_import: true)

      {
        imported: legacy.count,
        needs_structuring: legacy.where(needs_structuring: true).count,
        structured: legacy.where(needs_structuring: false).count
      }
    end

    def operational_alerts
      [].tap do |alerts|
        alerts << alert(:needs_info, "#{backlog_health[:needs_info]} issues need reporter info") if backlog_health[:needs_info].positive?
        alerts << alert(:review_queue, "#{training_counts['pending_review']} training examples need review") if training_counts["pending_review"].positive?
        alerts << alert(:exports, "#{training_export_metrics[:approved_ready]} approved examples are ready to export") if training_export_metrics[:approved_ready].positive?
        alerts << alert(:github, "#{github_webhook_metrics[:failed]} GitHub webhook deliveries failed") if github_webhook_metrics[:failed].positive?
        alerts << alert(:ai_suggestions, "#{ai_suggestion_metrics[:active]} AI suggestions are waiting for action") if ai_suggestion_metrics[:active].positive?
      end
    end

    def trend_points
      @trend_points ||= begin
        counts = trend_count_sets

        trend_dates.map do |date|
          { date: date }.merge(TREND_KEYS.index_with { |key| counts[key][date] || 0 })
        end
      end
    end

    def trend_totals
      @trend_totals ||= TREND_KEYS.index_with do |key|
        trend_points.sum { it[key] }
      end
    end

    def max_trend_value
      @max_trend_value ||= trend_points.flat_map { |point| TREND_KEYS.map { |key| point[key] } }.max || 0
    end

    def trend_count_sets
      {
        created_issues: date_counts(cards, :created_at),
        gate_one_completed: date_counts(resolution_records.gate_one_status_complete, :updated_at),
        gate_two_completed: date_counts(resolution_records.gate_two_status_complete, :updated_at),
        training_examples_created: date_counts(training_examples, :created_at),
        training_examples_exported: date_counts(training_examples.exported, :exported_at),
        github_webhook_failures: date_counts(github_webhook_deliveries.failed, :created_at),
        ai_suggestions_completed: date_counts(account.ai_runs.completed.where(run_type: AiRun::DISMISSIBLE_RUN_TYPES), :completed_at)
      }
    end

    def date_counts(relation, timestamp_column)
      relation
        .where(timestamp_column => period_started_at..period_ended_at)
        .pluck(timestamp_column)
        .compact
        .each_with_object(Hash.new(0)) { |timestamp, counts| counts[timestamp.to_date] += 1 }
    end

    def export_payload(export)
      {
        id: export.id,
        filename: export.filename,
        example_count: export.example_count,
        status: export.status,
        completed_at: export.completed_at
      }
    end

    def alert(kind, message)
      {
        kind: kind,
        message: message
      }
    end

    def percentage(numerator, denominator)
      return 0 if denominator.zero?

      ((numerator.to_f / denominator) * 100).round
    end
end
