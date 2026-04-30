module Card::Closeable
  extend ActiveSupport::Concern

  GateTwoIncomplete = Class.new(StandardError)

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

    def generate_training_example_if_ready!
      return unless resolution_record&.gate_one_complete? && resolution_record&.gate_two_complete?

      TrainingExamples::Generator.new(self).generate
    end
end
