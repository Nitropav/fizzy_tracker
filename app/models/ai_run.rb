class AiRun < ApplicationRecord
  STATUSES = %w[ pending completed failed ].freeze
  RUN_TYPES = %w[ card_quality_review issue_structuring legacy_issue_structuring resolution_draft duplicate_issue_suggestion ].freeze
  DISMISSIBLE_RUN_TYPES = %w[
    issue_structuring
    legacy_issue_structuring
    resolution_draft
    duplicate_issue_suggestion
  ].freeze

  belongs_to :account, default: -> { card&.account || user&.account }
  belongs_to :card, optional: true, touch: true
  belongs_to :user, optional: true

  enum :status, STATUSES.index_by(&:itself), default: :pending

  attribute :input_context, default: -> { {} }
  attribute :output, default: -> { {} }
  attribute :metadata, default: -> { {} }

  validates :account, :run_type, :status, presence: true
  validates :run_type, inclusion: { in: RUN_TYPES }
  validate :json_fields_are_present
  validate :card_matches_account
  validate :user_matches_account

  scope :latest_first, -> { order(created_at: :desc, id: :desc) }
  scope :card_quality_reviews, -> { where(run_type: "card_quality_review") }
  scope :issue_structurings, -> { where(run_type: "issue_structuring") }
  scope :legacy_issue_structurings, -> { where(run_type: "legacy_issue_structuring") }
  scope :resolution_drafts, -> { where(run_type: "resolution_draft") }
  scope :duplicate_issue_suggestions, -> { where(run_type: "duplicate_issue_suggestion") }

  def complete!(output:, metadata: {})
    update!(
      status: :completed,
      output: output,
      metadata: self.metadata.merge(metadata),
      completed_at: Time.current
    )
  end

  def fail!(error:, metadata: {})
    update!(
      status: :failed,
      output: { "error" => error.to_s },
      metadata: self.metadata.merge(metadata),
      completed_at: Time.current
    )
  end

  def dismiss!(user: Current.user, reason: nil)
    update!(
      metadata: metadata.merge(
        "dismissed_at" => Time.current.iso8601,
        "dismissed_by_id" => user&.id,
        "dismissed_reason" => reason.presence
      ).compact
    )
  end

  def mark_applied!(user: Current.user)
    update!(
      metadata: metadata.merge(
        "applied_at" => Time.current.iso8601,
        "applied_by_id" => user&.id
      ).compact
    )
  end

  def dismissible?
    DISMISSIBLE_RUN_TYPES.include?(run_type)
  end

  def dismissed?
    metadata["dismissed_at"].present?
  end

  def applied?
    metadata["applied_at"].present?
  end

  def active_suggestion?
    completed? && dismissible? && !dismissed? && !applied?
  end

  private
    def card_matches_account
      return if card.blank? || account.blank? || card.account_id == account_id

      errors.add(:card, "must belong to the AI run account")
    end

    def json_fields_are_present
      errors.add(:input_context, "can't be nil") if input_context.nil?
      errors.add(:output, "can't be nil") if output.nil?
      errors.add(:metadata, "can't be nil") if metadata.nil?
    end

    def user_matches_account
      return if user.blank? || account.blank? || user.account_id == account_id

      errors.add(:user, "must belong to the AI run account")
    end
end
