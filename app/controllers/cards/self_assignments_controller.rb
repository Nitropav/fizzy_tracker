class Cards::SelfAssignmentsController < ApplicationController
  include CardScoped
  before_action :ensure_can_claim_cactus_issues

  def create
    if @card.toggle_assignment(Current.user)
      respond_to do |format|
        format.html { redirect_back_or_to html_redirect_path, notice: "Assignment updated." }
        format.turbo_stream { render "cards/assignments/create" }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_back_or_to html_redirect_path, alert: "Could not update assignment." }
        format.turbo_stream { render "cards/assignments/create" }
        format.json { head :unprocessable_entity }
      end
    end
  end

  private
    def html_redirect_path
      params[:return_to] == "cactus_queue" ? cactus_queue_redirect_path : @card
    end

    def cactus_queue_redirect_path
      params[:queue_state].present? ? cactus_queues_path(state: params[:queue_state]) : cactus_queues_path
    end
end
