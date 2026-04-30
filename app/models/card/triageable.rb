module Card::Triageable
  extend ActiveSupport::Concern

  GateOneIncomplete = Class.new(StandardError)

  included do
    belongs_to :column, optional: true, touch: true

    scope :awaiting_triage, -> { active.where.missing(:column) }
    scope :triaged, -> { active.joins(:column) }
  end

  def triaged?
    active? && column.present?
  end

  def awaiting_triage?
    active? && !triaged?
  end

  def triage_into(column)
    raise "The column must belong to the card board" unless board == column.board
    ensure_gate_one_complete_for_resolution_record!

    transaction do
      resume
      update! column: column
      track_event "triaged", particulars: { column: column.name }
    end
  end

  def send_back_to_triage(skip_event: false)
    transaction do
      resume
      update! column: nil
      track_event "sent_back_to_triage" unless skip_event
    end
  end

  def triage_blocked_by_resolution_record?
    resolution_record.present? && !resolution_record.gate_one_complete?
  end

  private
    def ensure_gate_one_complete_for_resolution_record!
      return unless triage_blocked_by_resolution_record?

      missing = resolution_record.missing_gate_one_fields.map { it.to_s.humanize.downcase }.to_sentence
      raise GateOneIncomplete, "Complete Gate 1 before moving this card into work. Missing: #{missing}."
    end
end
