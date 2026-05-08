class Cards::DuplicateSuggestionsController < ApplicationController
  include CardScoped
  before_action :ensure_can_view_internal_issue_data

  def create
    Ai::RunScheduler.enqueue!(card: @card, user: Current.user, run_type: "duplicate_issue_suggestion")

    redirect_to card_path(@card, anchor: resolution_record_anchor), notice: "Duplicate issue check queued."
  end

  private
    def ensure_can_view_internal_issue_data
      head :forbidden unless Current.user.can_view_cactus_internal_issue_data?
    end

    def resolution_record_anchor
      ActionView::RecordIdentifier.dom_id(@card, :resolution_record)
    end
end
