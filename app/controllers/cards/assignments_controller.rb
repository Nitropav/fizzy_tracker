class Cards::AssignmentsController < ApplicationController
  include CardScoped

  def new
    @assigned_to = @card.assignees.active.alphabetically.where.not(id: Current.user)
    @users = @board.users.active.alphabetically.where.not(id: @card.assignees).where.not(id: Current.user)
    fresh_when etag: [ @users, @card.assignees ]
  end

  def create
    if @card.toggle_assignment @board.users.active.find(params[:assignee_id])
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back_or_to @card, notice: "Assignment updated." }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back_or_to @card, alert: "Could not update assignment." }
        format.json { head :unprocessable_entity }
      end
    end
  end
end
