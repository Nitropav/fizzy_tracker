class Cards::ResolutionRecordsController < ApplicationController
  include CardScoped
  before_action :ensure_can_update_cactus_resolution_record, only: :update

  def edit
    head :forbidden unless Current.user.can_update_cactus_gate_two? ||
      Current.user.can_view_cactus_queue? ||
      Current.user.can_review_training_examples?

    @resolution_record = @card.ensure_resolution_record
    @code_links = @card.code_links.latest_first
  end

  def update
    attributes = resolution_record_params
    record = @card.ensure_resolution_record
    record.update!(attributes)
    AuditEvent.record(
      action: "card.resolution_record_updated",
      auditable: @card,
      metadata: {
        card_id: @card.id,
        changed_fields: attributes.keys,
        gate_one_complete: record.gate_one_complete?,
        gate_two_complete: record.gate_two_complete?,
        workflow_state: @card.reload.cactus_workflow_state
      }
    )

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.html { redirect_to html_redirect_path, notice: "Training data saved." }
      format.json { render json: @card.resolution_record.as_json, status: :ok }
    end
  end

  private
    def html_redirect_path
      case params[:return_to]
      when "gate_two"
        edit_card_resolution_record_path(@card)
      when "cactus_queue"
        params[:queue_state].present? ? cactus_queues_path(state: params[:queue_state]) : cactus_queues_path
      else
        @card
      end
    end

    def resolution_record_params
      permitted = params.expect(card_resolution_record: [
        :problem_description,
        :reproduction_steps,
        :expected_behavior,
        :actual_behavior,
        :environment_context,
        :structured_summary,
        :priority,
        :category,
        :domain,
        :severity,
        :root_cause,
        :fix_summary,
        :verification_steps,
        :verified_at,
        suggested_primitives: [],
        linked_commit_shas: [],
        linked_pr_urls: []
      ])

      permitted.tap do |attributes|
        %i[ suggested_primitives linked_commit_shas linked_pr_urls ].each do |key|
          attributes[key] = normalize_list_param(attributes[key])
        end
      end
    end

    def normalize_list_param(value)
      Array(value).flat_map { it.to_s.split(/[\n,]/) }.map(&:strip).compact_blank
    end
end
