module TrainingExamples
  class Generator
    def initialize(card)
      @card = card
    end

    def generate
      record = card.resolution_record
      raise MissingResolutionRecord, "Card must have structured resolution data" unless record
      raise IncompleteGateOne, "Gate 1 must be complete before generating a training example" unless record.gate_one_complete?
      raise IncompleteGateTwo, "Gate 2 must be complete before generating a training example" unless record.gate_two_complete?

      training_example.update!(attributes_from(record))
      training_example
    end

    MissingResolutionRecord = Class.new(StandardError)
    IncompleteGateOne = Class.new(StandardError)
    IncompleteGateTwo = Class.new(StandardError)

    private
      attr_reader :card

      def training_example
        @training_example ||= card.training_examples.where(status: %w[ draft pending_review rejected ]).order(created_at: :desc).first ||
          card.training_examples.build
      end

      def attributes_from(record)
        context = Ai::CardContextBuilder.new(card).build

        {
          account: card.account,
          input_context: context,
          problem_summary: record.structured_summary.presence || record.problem_description,
          root_cause: record.root_cause,
          resolution_summary: record.fix_summary,
          verification_steps: record.verification_steps,
          metadata: metadata_from(context, record),
          status: "pending_review"
        }
      end

      def metadata_from(context, record)
        {
          "card_id" => card.id,
          "card_number" => card.number,
          "board_id" => card.board_id,
          "board_name" => card.board.name,
          "account_id" => card.account_id,
          "category" => record.category,
          "domain" => record.domain,
          "severity" => record.severity,
          "commit_shas" => commit_shas_from(context, record),
          "pr_urls" => pr_urls_from(context, record),
          "code_link_ids" => context["code_links"].map { it["id"] },
          "verified" => record.gate_two_complete?,
          "code_evidence_present" => record.code_evidence_present? || context["code_links"].any?,
          "context_version" => 1,
          "generated_at" => Time.current.iso8601,
          "cactus_workflow_state" => context.dig("card", "cactus_workflow_state"),
          "workflow_state" => context.dig("card", "workflow_state")
        }
      end

      def commit_shas_from(context, record)
        (record.linked_commit_shas + context["code_links"].filter_map { it["sha"] if it["external_type"] == "commit" }).uniq
      end

      def pr_urls_from(context, record)
        (record.linked_pr_urls + context["code_links"].filter_map { it["url"] if it["external_type"] == "pull_request" }).uniq
      end
  end
end
