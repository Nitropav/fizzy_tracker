class CactusPipelineMetrics
  Result = Data.define(
    :account,
    :generated_at,
    :workflow_counts,
    :gate_counts,
    :missing_gate_one_counts,
    :missing_gate_two_counts,
    :training_counts,
    :training_review_rate,
    :domain_counts,
    :code_link_counts,
    :github_linkage_rate,
    :ai_run_counts,
    :legacy_counts,
    :ai_acceptance_tracking_available
  )

  def initialize(account:)
    @account = account
  end

  def call
    Result.new(
      account: account,
      generated_at: Time.current,
      workflow_counts: workflow_counts,
      gate_counts: gate_counts,
      missing_gate_one_counts: missing_gate_counts(Card::ResolutionRecord::GATE_ONE_REQUIRED_FIELDS),
      missing_gate_two_counts: missing_gate_counts(Card::ResolutionRecord::GATE_TWO_REQUIRED_FIELDS),
      training_counts: training_counts,
      training_review_rate: training_review_rate,
      domain_counts: domain_counts,
      code_link_counts: code_link_counts,
      github_linkage_rate: github_linkage_rate,
      ai_run_counts: ai_run_counts,
      legacy_counts: legacy_counts,
      ai_acceptance_tracking_available: false
    )
  end

  private
    attr_reader :account

    def cards
      account.cards
    end

    def resolution_records
      Card::ResolutionRecord.where(account: account)
    end

    def training_examples
      account.training_examples
    end

    def workflow_counts
      query = Cards::CactusWorkflowQuery.new(cards)

      Card::CactusWorkflow::CACTUS_WORKFLOW_STATES.index_with do |state|
        query.for(state).count
      end
    end

    def gate_counts
      {
        total_records: resolution_records.count,
        gate_one_complete: resolution_records.gate_one_status_complete.count,
        gate_one_incomplete: resolution_records.gate_one_status_incomplete.count,
        gate_two_complete: resolution_records.gate_two_status_complete.count,
        gate_two_incomplete: resolution_records.gate_two_status_incomplete.count
      }
    end

    def missing_gate_counts(fields)
      fields.index_with do |field|
        resolution_records.where(field => [ nil, "" ]).count
      end
    end

    def training_counts
      TrainingExample::STATUSES.index_with do |status|
        training_examples.where(status: status).count
      end
    end

    def training_review_rate
      reviewed = training_examples.where(status: %w[ approved rejected exported ]).count
      percentage(reviewed, training_examples.count)
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

    def ai_run_counts
      AiRun::STATUSES.index_with do |status|
        account.ai_runs.where(status: status).count
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

    def percentage(numerator, denominator)
      return 0 if denominator.zero?

      ((numerator.to_f / denominator) * 100).round
    end
end
