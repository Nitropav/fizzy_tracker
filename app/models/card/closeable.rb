module Card::Closeable
  extend ActiveSupport::Concern

  GateTwoIncomplete = Class.new(StandardError)
  CodeEvidenceMissing = Class.new(StandardError)
  ResolutionNotReady = Class.new(StandardError)

  included do
    has_one :closure, dependent: :destroy

    scope :closed, -> { joins(:closure) }
    scope :open, -> { where.missing(:closure) }

    scope :recently_closed_first, -> { closed.order(closures: { created_at: :desc }) }
    scope :closed_at_window, ->(window) { closed.where(closures: { created_at: window }) }
    scope :closed_by, ->(users) { closed.where(closures: { user_id: Array(users) }) }
  end

  def closed?
    closure.present?
  end

  def open?
    !closed?
  end

  def closed_by
    closure&.user
  end

  def closed_at
    closure&.created_at
  end

  def close(user: Current.user)
    unless closed?
      ensure_gate_two_complete_for_resolution_record!
      ensure_code_evidence_present_for_resolution_record!
      ensure_cactus_workflow_ready_for_resolution!

      transaction do
        not_now&.destroy
        create_closure! user: user
        track_event :closed, creator: user
        generate_training_example_if_ready!
      end
    end
  end

  def resolve(user: Current.user)
    close(user: user)
  end

  def close_blocked_by_resolution_record?
    resolution_record.present? && !resolution_record.gate_two_complete?
  end

  def cactus_code_evidence_present?
    resolution_record.blank? ||
      resolution_record.code_evidence_present? ||
      code_links.exists?
  end

  def reopen(user: Current.user)
    if closed?
      transaction do
        closure&.destroy
        track_event :reopened, creator: user
      end
    end
  end

  private
    def ensure_gate_two_complete_for_resolution_record!
      return unless close_blocked_by_resolution_record?

      missing = resolution_record.missing_gate_two_fields.map { it.to_s.humanize.downcase }.to_sentence
      raise GateTwoIncomplete, "Complete Gate 2 before marking this card done. Missing: #{missing}."
    end

    def ensure_code_evidence_present_for_resolution_record!
      return if resolution_record.blank? ||
        !resolution_record.gate_one_complete? ||
        !resolution_record.gate_two_complete? ||
        cactus_workflow_state != "needs_review" ||
        cactus_code_evidence_present?

      raise CodeEvidenceMissing, "Add code evidence before resolving this issue. Link a GitHub commit or PR with CT-#{number}, or enter a commit SHA / PR URL in Gate 2."
    end

    def ensure_cactus_workflow_ready_for_resolution!
      return if resolution_record.blank? || cactus_workflow_state == "needs_review"

      raise ResolutionNotReady, "Move this issue into active work and complete review before resolving it."
    end

    def generate_training_example_if_ready!
      return unless resolution_record&.gate_one_complete? && resolution_record&.gate_two_complete? && cactus_code_evidence_present?

      TrainingExamples::Generator.new(self).generate
    end
end
