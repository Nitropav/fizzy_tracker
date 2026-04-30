class Cards::ClosuresController < ApplicationController
  include CardScoped

  def create
    capture_card_location
    @card.close
    refresh_stream_if_needed

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  rescue Card::Closeable::GateTwoIncomplete => error
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream_flash(alert: error.message), status: :unprocessable_entity
      end

      format.json do
        render json: {
          error: error.message,
          missing_gate_two_fields: @card.resolution_record.missing_gate_two_fields
        }, status: :unprocessable_entity
      end

      format.html { redirect_to @card, alert: error.message }
    end
  end

  def destroy
    @card.reopen
    refresh_stream_after_reopen

    respond_to do |format|
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  private
    def refresh_stream_after_reopen
      if @card.awaiting_triage?
        set_page_and_extract_portion_from @board.cards.awaiting_triage.latest.with_golden_first.preloaded
      end
    end
end
