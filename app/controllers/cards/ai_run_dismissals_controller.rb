class Cards::AiRunDismissalsController < ApplicationController
  include CardScoped
  before_action :set_ai_run
  before_action :ensure_can_dismiss_ai_run

  def create
    @ai_run.dismiss!(reason: params[:reason])

    redirect_to redirect_path, notice: "AI suggestion dismissed."
  end

  private
    def set_ai_run
      @ai_run = @card.ai_runs.completed.find(params.expect(:ai_run_id))
      raise ActiveRecord::RecordNotFound unless @ai_run.active_suggestion?
    end

    def ensure_can_dismiss_ai_run
      allowed = case @ai_run.run_type
      when "issue_structuring"
        Current.user.can_update_cactus_gate_one? || Current.user.can_update_cactus_classification?
      when "legacy_issue_structuring"
        Current.user.can_import_cactus_issues?
      when "resolution_draft"
        Current.user.can_update_cactus_gate_two?
      when "duplicate_issue_suggestion"
        Current.user.can_view_cactus_internal_issue_data?
      else
        false
      end

      head :forbidden unless allowed
    end

    def redirect_path
      case params[:return_to]
      when "gate_two"
        edit_card_resolution_record_path(@card)
      when "legacy_asana"
        legacy_imports_asana_issues_path(status: legacy_status_filter)
      else
        card_path(@card, anchor: ActionView::RecordIdentifier.dom_id(@card, :resolution_record))
      end
    end

    def legacy_status_filter
      params[:status].presence_in(LegacyImports::AsanaIssuesController::STATUSES) || "needs_structuring"
    end
end
