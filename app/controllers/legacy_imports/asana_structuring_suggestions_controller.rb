class LegacyImports::AsanaStructuringSuggestionsController < ApplicationController
  before_action :ensure_can_import_cactus_issues
  before_action :set_resolution_record

  def create
    Ai::RunScheduler.enqueue!(card: @resolution_record.card, user: Current.user, run_type: "legacy_issue_structuring")

    redirect_to legacy_imports_asana_issues_path(status: status_filter), notice: "Legacy structuring suggestion queued."
  end

  def apply
    ai_run = @resolution_record.card.ai_runs.legacy_issue_structurings.completed.find(params.expect(:ai_run_id))
    raise ActiveRecord::RecordNotFound unless ai_run.active_suggestion?

    applied_fields = apply_suggested_fields(ai_run)
    ai_run.mark_applied!

    redirect_to legacy_imports_asana_issues_path(status: status_filter),
      notice: "Applied #{applied_fields.size} suggested #{'field'.pluralize(applied_fields.size)}."
  end

  private
    def set_resolution_record
      @resolution_record = Card::ResolutionRecord.find_by!(
        id: params[:issue_id],
        account: Current.account,
        legacy_import: true,
        legacy_source: "asana"
      )
    end

    def apply_suggested_fields(ai_run)
      suggested_fields = ai_run.output.fetch("suggested_fields", {}).slice(*permitted_fields).compact_blank
      current_attributes = @resolution_record.attributes.slice(*permitted_fields)
      blank_field_updates = suggested_fields.select { |field, _value| current_attributes[field].blank? }

      @resolution_record.update!(blank_field_updates) if blank_field_updates.any?
      blank_field_updates.keys
    end

    def permitted_fields
      %w[
        problem_description
        reproduction_steps
        expected_behavior
        actual_behavior
        environment_context
        structured_summary
        priority
        category
        domain
        severity
        root_cause
        fix_summary
        verification_steps
      ]
    end

    def status_filter
      params[:status].presence_in(LegacyImports::AsanaIssuesController::STATUSES) || "needs_structuring"
    end
end
