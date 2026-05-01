class Card::ResolutionRecord < ApplicationRecord
  STATUSES = %w[ incomplete complete ].freeze

  GATE_ONE_REQUIRED_FIELDS = %i[
    problem_description
    reproduction_steps
    expected_behavior
    actual_behavior
    environment_context
  ].freeze

  GATE_TWO_REQUIRED_FIELDS = %i[
    root_cause
    fix_summary
    verification_steps
  ].freeze

  belongs_to :account, default: -> { card&.account }
  belongs_to :card, class_name: "::Card", touch: true
  belongs_to :verified_by, class_name: "User", optional: true

  enum :gate_one_status, STATUSES.index_by(&:itself), prefix: :gate_one_status, default: :incomplete
  enum :gate_two_status, STATUSES.index_by(&:itself), prefix: :gate_two_status, default: :incomplete

  attribute :suggested_primitives, default: -> { [] }
  attribute :linked_commit_shas, default: -> { [] }
  attribute :linked_pr_urls, default: -> { [] }
  attribute :legacy_metadata, default: -> { {} }

  before_validation :sync_gate_statuses
  before_validation :sync_legacy_structuring_status, if: :legacy_import?

  validates :account, :card, presence: true
  validates :card_id, uniqueness: true
  validates :legacy_external_id, uniqueness: { scope: [ :account_id, :legacy_source ], allow_blank: true }
  validate :account_matches_card
  validate :legacy_source_present_for_legacy_import

  def missing_gate_one_fields
    missing_fields(GATE_ONE_REQUIRED_FIELDS)
  end

  def missing_gate_two_fields
    missing_fields(GATE_TWO_REQUIRED_FIELDS)
  end

  def gate_one_complete?
    missing_gate_one_fields.empty?
  end

  def gate_two_complete?
    missing_gate_two_fields.empty?
  end

  def linked_commit_shas
    Array(super).compact_blank
  end

  def linked_pr_urls
    Array(super).compact_blank
  end

  def suggested_primitives
    Array(super).compact_blank
  end

  def code_evidence_present?
    linked_commit_shas.any? || linked_pr_urls.any?
  end

  def legacy?
    legacy_import?
  end

  def legacy_resolved?
    legacy_metadata["completed"] == true || legacy_metadata["completed_at"].present?
  end

  def legacy_structuring_complete?
    gate_one_complete? && (!legacy_resolved? || gate_two_complete?)
  end

  private
    def sync_gate_statuses
      self.gate_one_status = gate_one_complete? ? "complete" : "incomplete"
      self.gate_two_status = gate_two_complete? ? "complete" : "incomplete"
    end

    def missing_fields(fields)
      fields.select { public_send(it).blank? }
    end

    def account_matches_card
      return if account.blank? || card.blank? || account_id == card.account_id

      errors.add(:account, "must match the card account")
    end

    def sync_legacy_structuring_status
      self.needs_structuring = !legacy_structuring_complete?
    end

    def legacy_source_present_for_legacy_import
      return unless legacy_import?

      errors.add(:legacy_source, "must be present for legacy imports") if legacy_source.blank?
      errors.add(:legacy_external_id, "must be present for legacy imports") if legacy_external_id.blank?
      errors.add(:legacy_imported_at, "must be present for legacy imports") if legacy_imported_at.blank?
    end
end
