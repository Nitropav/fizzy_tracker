class CactusQueuesController < ApplicationController
  before_action :ensure_can_view_cactus_queue

  def index
    @state = params[:state].presence_in(Cards::CactusWorkflowQuery::STATES)
    @cards = Cards::CactusWorkflowQuery.new(Current.user.accessible_cards).for(@state)
      .includes(:board, :column, :resolution_record, :closure, :not_now, :assignees, training_examples: :reviewed_by)
      .latest
    @assignable_users_by_board_id = assignable_users_by_board_id(@cards)
  end

  private
    def assignable_users_by_board_id(cards)
      cards.map(&:board).uniq.index_with { it.users.active.alphabetically.select(&:can_work_cactus_issues?) }.transform_keys(&:id)
    end
end
