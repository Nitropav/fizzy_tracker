class Cards::AssignmentsController < ApplicationController
  include CardScoped
  before_action :ensure_can_assign_cactus_issues

  def new
    @assigned_to = @card.assignees.active.alphabetically.where.not(id: Current.user)
    @users = @board.users.active.alphabetically.where.not(id: @card.assignees).where.not(id: Current.user).select(&:can_work_cactus_issues?)
    fresh_when etag: [ @users, @card.assignees ]
  end

  def create
    assignee = @board.users.active.find(params[:assignee_id])
    return head :forbidden unless assignee.can_work_cactus_issues?

    was_assigned = @card.assignees.exists?(assignee.id)
    if @card.toggle_assignment assignee
      AuditEvent.record(
        action: was_assigned ? "card.unassigned" : "card.assigned",
        auditable: @card,
        metadata: {
          card_id: @card.id,
          assignee_id: assignee.id,
          assignee_name: assignee.name
        }
      )
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
