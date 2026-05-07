class Cards::GateOneAnswersController < ApplicationController
  include CardScoped
  before_action :ensure_can_update_cactus_gate_one

  def update
    record = @card.ensure_resolution_record
    record.update!(field_name => answer_value)
    AuditEvent.record(
      action: "card.gate_one_updated",
      auditable: @card,
      metadata: {
        card_id: @card.id,
        field: field_name,
        gate_one_complete: record.gate_one_complete?,
        workflow_state: @card.reload.cactus_workflow_state
      }
    )

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.html { redirect_to @card, notice: notice_for(record) }
      format.json do
        render json: record.as_json.merge(
          cactus_workflow_state: @card.reload.cactus_workflow_state,
          missing_gate_one_fields: record.missing_gate_one_fields
        ), status: :ok
      end
    end
  end

  private
    def answer_params
      params.expect(gate_one_answer: [ :field, :value ])
    end

    def field_name
      @field_name ||= answer_params[:field].to_s.tap do |field|
        raise ActionController::BadRequest, "Unsupported Gate 1 field" unless allowed_fields.include?(field)
      end
    end

    def answer_value
      answer_params[:value].to_s.strip
    end

    def allowed_fields
      Card::ResolutionRecord::GATE_ONE_REQUIRED_FIELDS.map(&:to_s)
    end

    def notice_for(record)
      if record.gate_one_complete?
        "Gate 1 complete. This card is ready for triage."
      else
        "Reporter information saved."
      end
    end
end
