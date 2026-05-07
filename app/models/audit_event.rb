class AuditEvent < ApplicationRecord
  belongs_to :account
  belongs_to :user, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  attribute :metadata, default: -> { {} }

  validates :action, :account, presence: true
  validate :user_matches_account
  validate :auditable_matches_account

  scope :latest_first, -> { order(created_at: :desc, id: :desc) }

  def self.record(action:, account: Current.account, user: Current.user, auditable: nil, metadata: {})
    return if account.blank?

    create!(
      account: account,
      user: user,
      action: action,
      auditable: auditable,
      metadata: normalize_metadata(metadata),
      request_id: Current.request_id,
      ip_address: Current.ip_address,
      user_agent: Current.user_agent
    )
  rescue => error
    Rails.logger.error("[AuditEvent] #{error.class}: #{error.message}")
    nil
  end

  def self.normalize_metadata(metadata)
    (metadata || {}).to_h.deep_stringify_keys
  end

  private
    def user_matches_account
      return if user.blank? || account.blank? || user.account_id == account_id

      errors.add(:user, "must belong to the audit event account")
    end

    def auditable_matches_account
      return if auditable.blank? || account.blank?
      return unless auditable.respond_to?(:account_id)
      return if auditable.account_id == account_id

      errors.add(:auditable, "must belong to the audit event account")
    end
end
