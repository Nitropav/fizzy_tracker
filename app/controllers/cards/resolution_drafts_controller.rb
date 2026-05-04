class Cards::ResolutionDraftsController < ApplicationController
  include CardScoped
  before_action :ensure_can_update_cactus_gate_two

  def create
    ai_run = Ai::ResolutionDraftService.new(@card).suggest

    if ai_run.failed?
      redirect_to redirect_path, alert: "Resolution draft failed: #{ai_run.output['error']}"
    else
      redirect_to redirect_path, notice: "Resolution draft generated."
    end
  end

  def apply
    ai_run = @card.ai_runs.resolution_drafts.completed.find(params.expect(:ai_run_id))
    raise ActiveRecord::RecordNotFound unless ai_run.active_suggestion?

    applied_fields = apply_suggested_fields(ai_run)
    ai_run.mark_applied!

    redirect_to redirect_path,
      notice: "Applied #{applied_fields.size} suggested #{'field'.pluralize(applied_fields.size)}."
  end

  private
    def redirect_path
      if params[:return_to] == "gate_two"
        edit_card_resolution_record_path(@card)
      else
        card_path(@card, anchor: ActionView::RecordIdentifier.dom_id(@card, :resolution_record))
      end
    end

    def apply_suggested_fields(ai_run)
      record = @card.ensure_resolution_record
      suggested_fields = ai_run.output.fetch("suggested_fields", {}).slice(*permitted_fields).compact_blank
      current_attributes = record.attributes.slice(*permitted_fields)
      blank_field_updates = suggested_fields.select { |field, _value| current_attributes[field].blank? }

      record.update!(blank_field_updates) if blank_field_updates.any?
      blank_field_updates.keys
    end

    def permitted_fields
      Card::ResolutionRecord::GATE_TWO_REQUIRED_FIELDS.map(&:to_s)
    end
end
