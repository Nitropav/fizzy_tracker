module Cards
  class CactusWorkflowQuery
    STATES = Card::CactusWorkflow::CACTUS_WORKFLOW_STATES.freeze

    def initialize(scope)
      @scope = scope
    end

    def for(state)
      case state.to_s
      when "draft" then scope.drafted
      when "needs_info" then needs_info
      when "open" then open
      when "in_progress" then in_progress
      when "needs_review" then needs_review
      when "resolved" then resolved
      when "closed" then closed
      else scope.published.latest
      end
    end

    private
      attr_reader :scope

      def needs_info
        active_published.left_joins(:resolution_record)
          .where(card_resolution_records: { id: nil })
          .or(active_published.left_joins(:resolution_record).where(card_resolution_records: { gate_one_status: "incomplete" }))
      end

      def open
        scope.awaiting_triage.joins(:resolution_record)
          .where(card_resolution_records: { gate_one_status: "complete" })
      end

      def in_progress
        scope.triaged.joins(:resolution_record)
          .where(card_resolution_records: { gate_one_status: "complete", gate_two_status: "incomplete" })
      end

      def needs_review
        scope.triaged.joins(:resolution_record)
          .where(card_resolution_records: { gate_two_status: "complete" })
      end

      def resolved
        scope.closed.where.not(id: approved_training_example_card_ids)
      end

      def closed
        scope.closed.where(id: approved_training_example_card_ids)
      end

      def active_published
        scope.open.published.where.missing(:not_now)
      end

      def approved_training_example_card_ids
        TrainingExample.approved.select(:card_id)
      end
  end
end
