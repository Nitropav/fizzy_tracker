class Boards::BugReportsController < ApplicationController
  include BoardScoped

  def new
    @card = @board.cards.build
    @resolution_record = Card::ResolutionRecord.new
  end

  def create
    issue_creator = Cards::IssueCreator.new(board: @board, user: Current.user, attributes: bug_report_params)
    @card = issue_creator.card
    @resolution_record = issue_creator.resolution_record

    unless issue_creator.save
      render :new, status: :unprocessable_entity
      return
    end

    AuditEvent.record(
      action: "issue.created",
      auditable: @card,
      metadata: {
        card_id: @card.id,
        project_id: @board.id,
        gate_one_complete: @resolution_record.gate_one_complete?,
        workflow_state: @card.cactus_workflow_state
      }
    )

    redirect_to @card, notice: issue_creator.creation_notice
  end

  private
    def bug_report_params
      params.expect(bug_report: [
        :title,
        :description,
        :priority,
        :problem_description,
        :reproduction_steps,
        :expected_behavior,
        :actual_behavior,
        :environment_context,
        attachments: []
      ])
    end
end
