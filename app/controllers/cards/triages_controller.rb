class Cards::TriagesController < ApplicationController
  include CardScoped
  before_action :ensure_can_update_cactus_classification

  def create
    column = @card.board.columns.find(params[:column_id])
    @card.triage_into(column)

    respond_to do |format|
      format.html { redirect_to @card }
      format.turbo_stream { head :no_content }
      format.json { head :no_content }
    end
  rescue Card::Triageable::GateOneIncomplete => error
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream_flash(alert: error.message), status: :unprocessable_entity
      end

      format.json do
        render json: {
          error: error.message,
          missing_gate_one_fields: @card.resolution_record.missing_gate_one_fields
        }, status: :unprocessable_entity
      end

      format.html { redirect_to @card, alert: error.message }
    end
  end

  def destroy
    @card.send_back_to_triage

    respond_to do |format|
      format.html { redirect_to @card }
      format.json { head :no_content }
    end
  end
end
