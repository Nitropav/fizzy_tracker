class CactusWorksController < ApplicationController
  before_action :ensure_can_work_cactus_issues

  def show
    cards = Current.user.accessible_cards
      .preload(:board, :column, :resolution_record, :closure, :assignments, :assignees, training_examples: :reviewed_by)

    workflow_query = Cards::CactusWorkflowQuery.new(cards)

    @assigned_cards = cards.assigned_to(Current.user).published.open.latest.limit(20)
    @needs_gate_two_cards = workflow_query.for("in_progress").assigned_to(Current.user).latest.limit(20)
    @needs_review_cards = workflow_query.for("needs_review").assigned_to(Current.user).latest.limit(20)
    @ready_to_claim_cards = workflow_query.for("in_progress").unassigned.latest.limit(20)
    @recently_resolved_cards = workflow_query.for("resolved").assigned_to(Current.user).latest.limit(10)
  end
end
