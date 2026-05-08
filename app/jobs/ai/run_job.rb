module Ai
  class RunJob < ApplicationJob
    queue_as :backend

    discard_on ActiveJob::DeserializationError

    def perform(ai_run)
      return unless ai_run.pending?

      Current.with(account: ai_run.account, user: ai_run.user, identity: ai_run.user&.identity) do
        service_for(ai_run).public_send(method_for(ai_run), ai_run: ai_run)
      end
    end

    private
      def service_for(ai_run)
        case ai_run.run_type
        when "card_quality_review"
          CardQualityReviewService.new(ai_run.card, user: ai_run.user)
        when "issue_structuring"
          IssueStructuringService.new(ai_run.card, user: ai_run.user)
        when "legacy_issue_structuring"
          LegacyIssueStructuringService.new(ai_run.card, user: ai_run.user)
        when "resolution_draft"
          ResolutionDraftService.new(ai_run.card, user: ai_run.user)
        when "duplicate_issue_suggestion"
          DuplicateIssueSuggestionService.new(ai_run.card, user: ai_run.user)
        else
          raise ArgumentError, "Unsupported AI run type: #{ai_run.run_type}"
        end
      end

      def method_for(ai_run)
        ai_run.run_type == "card_quality_review" ? :review : :suggest
      end
  end
end
