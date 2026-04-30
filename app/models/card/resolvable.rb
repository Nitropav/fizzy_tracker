module Card::Resolvable
  extend ActiveSupport::Concern

  included do
    has_one :resolution_record, class_name: "Card::ResolutionRecord", dependent: :destroy

    scope :with_resolution_records, -> { joins(:resolution_record) }
    scope :missing_resolution_records, -> { where.missing(:resolution_record) }
  end

  def ensure_resolution_record
    resolution_record || create_resolution_record!
  rescue ActiveRecord::RecordNotUnique
    association(:resolution_record).reset
    resolution_record
  end

  def gate_one_complete?
    resolution_record&.gate_one_complete? || false
  end

  def gate_two_complete?
    resolution_record&.gate_two_complete? || false
  end
end
