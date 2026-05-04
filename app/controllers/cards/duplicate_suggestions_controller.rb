class Cards::DuplicateSuggestionsController < ApplicationController
  include CardScoped
  before_action :ensure_can_view_internal_issue_data

  def create
    ai_run = Ai::DuplicateIssueSuggestionService.new(@card).suggest

    if ai_run.failed?
      redirect_to card_path(@card, anchor: resolution_record_anchor), alert: "Duplicate issue check failed: #{ai_run.output['error']}"
    else
      redirect_to card_path(@card, anchor: resolution_record_anchor), notice: "Duplicate issue check completed."
    end
  end

  private
    def ensure_can_view_internal_issue_data
      head :forbidden unless Current.user.can_view_cactus_internal_issue_data?
    end

    def resolution_record_anchor
      ActionView::RecordIdentifier.dom_id(@card, :resolution_record)
    end
end
