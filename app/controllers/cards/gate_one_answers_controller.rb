class Cards::GateOneAnswersController < ApplicationController
  include CardScoped

  def update
    @card.ensure_resolution_record.update!(field_name => answer_value)

    respond_to do |format|
      format.turbo_stream { render_card_replacement }
      format.html { redirect_to @card, notice: "Reporter information saved" }
      format.json { render json: @card.resolution_record.as_json, status: :ok }
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
end
