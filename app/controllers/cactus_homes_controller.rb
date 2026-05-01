class CactusHomesController < ApplicationController
  def show
    cards = Current.user.accessible_cards
    workflow_query = Cards::CactusWorkflowQuery.new(cards)

    @workflow_counts = Cards::CactusWorkflowQuery::STATES.index_with { |state| workflow_query.for(state).count }
    @assigned_count = Current.user.assigned_cards.published.open.count
    @training_review_count = Current.user.admin? ? Current.account.training_examples.pending_review.count : nil
  end
end
