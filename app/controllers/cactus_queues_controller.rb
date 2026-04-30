class CactusQueuesController < ApplicationController
  def index
    @state = params[:state].presence_in(Cards::CactusWorkflowQuery::STATES)
    @cards = Cards::CactusWorkflowQuery.new(Current.user.accessible_cards).for(@state)
      .includes(:board, :column, :resolution_record, :closure, :not_now, training_examples: :reviewed_by)
      .latest
  end
end
