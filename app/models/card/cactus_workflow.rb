module Card::CactusWorkflow
  extend ActiveSupport::Concern

  CACTUS_WORKFLOW_STATES = %w[
    draft
    needs_info
    open
    in_progress
    needs_review
    resolved
    closed
  ].freeze

  def cactus_workflow_state
    case
    when drafted? then "draft"
    when closed? && training_examples.approved.exists? then "closed"
    when closed? then "resolved"
    when resolution_record.blank? || !resolution_record.gate_one_complete? then "needs_info"
    when !triaged? then "open"
    when resolution_record.gate_two_complete? then "needs_review"
    else "in_progress"
    end
  end

  def cactus_workflow_state_label
    cactus_workflow_state.humanize
  end
end
