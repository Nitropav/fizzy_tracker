class CactusHomesController < ApplicationController
  def show
    cards = Current.user.accessible_cards
    workflow_query = Cards::CactusWorkflowQuery.new(cards)

    @workflow_counts = Cards::CactusWorkflowQuery::STATES.index_with { |state| workflow_query.for(state).count }
    @assigned_count = Current.user.assigned_cards.published.open.count
    @training_review_count = Current.user.can_review_training_examples? ? Current.account.training_examples.pending_review.count : nil
    @legacy_needs_structuring_count = Current.user.can_import_cactus_issues? ? legacy_asana_needs_structuring_count : nil
  end

  private
    def legacy_asana_needs_structuring_count
      Card::ResolutionRecord.where(
        account: Current.account,
        legacy_import: true,
        legacy_source: "asana",
        needs_structuring: true
      ).count
    end
end
