class Cards::ResolutionsController < ApplicationController
  include CardScoped

  def create
    capture_card_location
    training_example = @card.resolve
    refresh_stream_if_needed

    respond_to do |format|
      format.html { redirect_to @card, notice: resolved_notice(training_example) }
      format.turbo_stream { render "cards/closures/create" }
      format.json do
        render json: {
          cactus_workflow_state: @card.reload.cactus_workflow_state,
          training_example_id: training_example&.id
        }, status: :created
      end
    end
  rescue Card::Closeable::GateTwoIncomplete => error
    respond_to do |format|
      format.html { redirect_to @card, alert: error.message }
      format.turbo_stream do
        render turbo_stream: turbo_stream_flash(alert: error.message), status: :unprocessable_entity
      end
      format.json do
        render json: {
          error: error.message,
          missing_gate_two_fields: @card.resolution_record.missing_gate_two_fields
        }, status: :unprocessable_entity
      end
    end
  end

  private
    def resolved_notice(training_example)
      if training_example
        "Card resolved. Training example is ready for review."
      else
        "Card resolved."
      end
    end
end
