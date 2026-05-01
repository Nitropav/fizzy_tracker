class Card::CodeLink < ApplicationRecord
  PROVIDERS = %w[ github ].freeze
  EXTERNAL_TYPES = %w[ commit pull_request ].freeze

  belongs_to :account, default: -> { card&.account }
  belongs_to :card, class_name: "::Card", touch: true

  attribute :metadata, default: -> { {} }

  validates :account, :card, :provider, :external_type, :external_id, presence: true
  validates :provider, inclusion: { in: PROVIDERS }
  validates :external_type, inclusion: { in: EXTERNAL_TYPES }
  validates :external_id, uniqueness: { scope: %i[ account_id provider external_type card_id ] }
  validate :metadata_is_present
  validate :account_matches_card

  scope :chronologically, -> { order(:created_at, :id) }
  scope :latest_first, -> { order(created_at: :desc, id: :desc) }
  scope :commits, -> { where(external_type: "commit") }
  scope :pull_requests, -> { where(external_type: "pull_request") }

  def commit?
    external_type == "commit"
  end

  def pull_request?
    external_type == "pull_request"
  end

  private
    def account_matches_card
      return if account.blank? || card.blank? || account_id == card.account_id

      errors.add(:account, "must match the card account")
    end

    def metadata_is_present
      errors.add(:metadata, "can't be nil") if metadata.nil?
    end
end
