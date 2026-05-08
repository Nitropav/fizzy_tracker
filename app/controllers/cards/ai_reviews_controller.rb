class Cards::AiReviewsController < ApplicationController
  include CardScoped

  def create
    @ai_run = Ai::RunScheduler.enqueue!(card: @card, user: Current.user, run_type: "card_quality_review")

    respond_to do |format|
      format.html { redirect_to @card, notice: "Training quality review queued." }
      format.json { render json: queued_payload, status: :accepted }
    end
  end

  private
    def queued_payload
      {
        "id" => @ai_run.id,
        "status" => @ai_run.status,
        "run_type" => @ai_run.run_type
      }
    end
end
