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

  CATEGORIES = [
    "bug",
    "feature request",
    "question",
    "configuration error",
    "task"
  ].freeze

  DOMAINS = [
    "assembly config",
    "pricing",
    "glass visibility",
    "certification",
    "sales document",
    "quote/work order",
    "customer account",
    "ui/ux",
    "integration",
    "performance",
    "training data",
    "other"
  ].freeze

  SEVERITIES = [
    "blocks ordering",
    "blocks workflow",
    "degrades experience",
    "cosmetic",
    "needs investigation"
  ].freeze

  PRIORITIES = [
    "urgent",
    "high",
    "normal",
    "low"
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

  scope :legacy_training_candidates, -> { where(legacy_import: true, gate_one_status: "complete", gate_two_status: "complete") }

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

  def legacy_training_candidate_ready?
    legacy_import? && gate_one_complete? && gate_two_complete?
  end

  def legacy_training_candidate_blockers
    [
      *missing_gate_one_fields.map { "Gate 1 #{it.to_s.humanize.downcase}" },
      *missing_gate_two_fields.map { "Gate 2 #{it.to_s.humanize.downcase}" }
    ]
  end

  def legacy_structuring_blockers
    [
      *missing_gate_one_fields.map { "Gate 1 #{it.to_s.humanize.downcase}" },
      *(legacy_resolved? ? missing_gate_two_fields.map { "Gate 2 #{it.to_s.humanize.downcase}" } : [])
    ]
  end

  def legacy_attachments
    legacy_metadata_entries("attachments").select do |attachment|
      attachment["name"].present? || legacy_attachment_url(attachment).present?
    end
  end

  def legacy_attachment_url(attachment)
    attachment["permanent_url"].presence || attachment["view_url"].presence || attachment["download_url"].presence
  end

  def legacy_attachment_preview_url(attachment)
    return if legacy_attachment_blob(attachment).present?
    return unless legacy_attachment_image?(attachment)

    attachment["view_url"].presence || attachment["download_url"].presence
  end

  def legacy_attachment_image?(attachment)
    blob = legacy_attachment_blob(attachment)
    return blob.image? if blob.present?

    content_type = attachment["cactus_blob_content_type"].presence ||
      attachment["content_type"].presence ||
      attachment["mime_type"].presence
    return content_type.start_with?("image/") if content_type.present?

    [ attachment["name"], attachment["view_url"], attachment["download_url"] ].compact.any? do |value|
      value.match?(/\.(png|jpe?g|gif|webp|bmp|svg)(?:[?#]|\z)/i)
    end
  end

  def legacy_attachment_blob(attachment)
    signed_id = attachment["cactus_blob_signed_id"]
    return if signed_id.blank?

    ActiveStorage::Blob.find_signed(signed_id)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def legacy_comment_stories
    legacy_metadata_entries("stories").select do |story|
      legacy_comment_story?(story) && story["text"].present?
    end
  end

  def legacy_source_context_present?
    legacy_metadata["assignee"].present? ||
      legacy_metadata["created_by"].present? ||
      legacy_attachments.any? ||
      legacy_comment_stories.any?
  end

  def self.category_options(current_value = nil)
    options_with_current(CATEGORIES, current_value)
  end

  def self.domain_options(current_value = nil)
    options_with_current(DOMAINS, current_value)
  end

  def self.severity_options(current_value = nil)
    options_with_current(SEVERITIES, current_value)
  end

  def self.priority_options(current_value = nil)
    options_with_current(PRIORITIES, current_value)
  end

  private
    def self.options_with_current(options, current_value)
      (options + [ current_value ]).compact_blank.uniq
    end

    def sync_gate_statuses
      self.gate_one_status = gate_one_complete? ? "complete" : "incomplete"
      self.gate_two_status = gate_two_complete? ? "complete" : "incomplete"
    end

    def missing_fields(fields)
      fields.select { public_send(it).blank? }
    end

    def legacy_metadata_entries(key)
      Array(legacy_metadata[key]).select { it.is_a?(Hash) }
    end

    def legacy_comment_story?(story)
      story["type"] == "comment" || story["resource_subtype"] == "comment_added"
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
