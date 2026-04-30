class TrainingExample < ApplicationRecord
  STATUSES = %w[ draft pending_review approved rejected exported ].freeze

  belongs_to :account, default: -> { card&.account }
  belongs_to :card
  belongs_to :reviewed_by, class_name: "User", optional: true

  enum :status, STATUSES.index_by(&:itself), default: :draft

  attribute :input_context, default: -> { {} }
  attribute :metadata, default: -> { {} }

  validates :account, :card, :input_context, :metadata, presence: true
  validate :account_matches_card
  validate :reviewer_matches_account

  scope :reviewable, -> { where(status: :pending_review) }
  scope :approved_for_export, -> { where(status: :approved) }
  scope :latest_first, -> { order(created_at: :desc, id: :desc) }

  def submit_for_review!
    pending_review!
  end

  def approve!(reviewer:, notes: nil)
    update!(
      status: :approved,
      reviewed_by: reviewer,
      review_notes: notes,
      reviewed_at: Time.current
    )
  end

  def reject!(reviewer:, notes: nil)
    update!(
      status: :rejected,
      reviewed_by: reviewer,
      review_notes: notes,
      reviewed_at: Time.current
    )
  end

  def mark_exported!
    update!(status: :exported, exported_at: Time.current)
  end

  private
    def account_matches_card
      return if account.blank? || card.blank? || account_id == card.account_id

      errors.add(:account, "must match the card account")
    end

    def reviewer_matches_account
      return if reviewed_by.blank? || account.blank? || reviewed_by.account_id == account_id

      errors.add(:reviewed_by, "must belong to the training example account")
    end
end
