module Github
  class WebhookDelivery < ApplicationRecord
    self.table_name = "github_webhook_deliveries"

    STATUSES = %w[ pending processing processed failed ].freeze

    belongs_to :account

    attribute :payload, default: -> { {} }
    attribute :status, :string, default: "pending"

    enum :status, STATUSES.index_by(&:itself), default: :pending

    validates :account, :delivery_id, :event, :payload_sha256, presence: true
    validates :delivery_id, uniqueness: { scope: :account_id }

    scope :latest_first, -> { order(created_at: :desc, id: :desc) }

    def retryable?
      failed? && payload.present?
    end

    def process!
      WebhookDeliveryProcessor.new(self).process
    end

    def mark_processing!(event:, payload_sha256:, payload:)
      update!(
        event: event,
        payload_sha256: payload_sha256,
        payload: payload,
        status: "processing",
        error_message: nil
      )
    end

    def mark_processed!(linked_code_references_count)
      update!(
        linked_code_references_count: linked_code_references_count,
        status: "processed",
        processed_at: Time.current,
        error_message: nil
      )
    end

    def mark_failed!(message)
      update!(
        status: "failed",
        processed_at: Time.current,
        error_message: message
      )
    end
  end
end
