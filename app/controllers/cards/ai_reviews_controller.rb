class Cards::AiReviewsController < ApplicationController
  include CardScoped

  def create
    @ai_run = Ai::CardQualityReviewService.new(@card).review

    respond_to do |format|
      format.html { redirect_to @card, flash_for_ai_run }
      format.json { render json: @ai_run.output, status: @ai_run.failed? ? :unprocessable_entity : :created }
    end
  end

  private
    def flash_for_ai_run
      if @ai_run.failed?
        { alert: "Training quality review failed: #{@ai_run.output['error']}" }
      else
        { notice: "Training quality review completed." }
      end
    end
end
