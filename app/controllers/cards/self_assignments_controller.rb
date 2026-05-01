class Cards::SelfAssignmentsController < ApplicationController
  include CardScoped

  def create
    if @card.toggle_assignment(Current.user)
      respond_to do |format|
        format.html { redirect_back_or_to @card, notice: "Assignment updated." }
        format.turbo_stream { render "cards/assignments/create" }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_back_or_to @card, alert: "Could not update assignment." }
        format.turbo_stream { render "cards/assignments/create" }
        format.json { head :unprocessable_entity }
      end
    end
  end
end
