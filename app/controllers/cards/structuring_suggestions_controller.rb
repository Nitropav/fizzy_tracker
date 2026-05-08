class Cards::StructuringSuggestionsController < ApplicationController
  include CardScoped
  before_action :ensure_can_manage_issue_structuring_suggestions

  def create
    Ai::RunScheduler.enqueue!(card: @card, user: Current.user, run_type: "issue_structuring")

    redirect_to card_path(@card, anchor: resolution_record_anchor), notice: "Issue structuring suggestion queued."
  end

  def apply
    ai_run = @card.ai_runs.issue_structurings.completed.find(params.expect(:ai_run_id))
    raise ActiveRecord::RecordNotFound unless ai_run.active_suggestion?

    applied_fields = apply_suggested_fields(ai_run)
    ai_run.mark_applied!

    redirect_to card_path(@card, anchor: resolution_record_anchor),
      notice: "Applied #{applied_fields.size} suggested #{'field'.pluralize(applied_fields.size)}."
  end

  private
    def resolution_record_anchor
      ActionView::RecordIdentifier.dom_id(@card, :resolution_record)
    end

    def ensure_can_manage_issue_structuring_suggestions
      head :forbidden unless Current.user.can_update_cactus_gate_one? || Current.user.can_update_cactus_classification?
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
      [
        *gate_one_fields,
        *classification_fields
      ]
    end

    def gate_one_fields
      return [] unless Current.user.can_update_cactus_gate_one?

      Card::ResolutionRecord::GATE_ONE_REQUIRED_FIELDS.map(&:to_s)
    end

    def classification_fields
      return [] unless Current.user.can_update_cactus_classification?

      %w[
        structured_summary
        priority
        category
        domain
        severity
      ]
    end
end
