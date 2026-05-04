require "test_helper"

class Github::WebhookDeliveryTest < ActiveSupport::TestCase
  test "tracks processing lifecycle" do
    delivery = Github::WebhookDelivery.create!(
      account: accounts("37s"),
      delivery_id: "delivery-1",
      event: "push",
      payload_sha256: Digest::SHA256.hexdigest("{}"),
      payload: {}
    )

    delivery.mark_processing!(
      event: "pull_request",
      payload_sha256: Digest::SHA256.hexdigest("{\"ok\":true}"),
      payload: { "ok" => true }
    )
    assert delivery.processing?
    assert_equal "pull_request", delivery.event
    assert_equal({ "ok" => true }, delivery.payload)

    delivery.mark_processed!(2)
    assert delivery.processed?
    assert_equal 2, delivery.linked_code_references_count
    assert delivery.processed_at.present?
  end

  test "delivery id is unique per account" do
    account = accounts("37s")
    attrs = {
      account: account,
      delivery_id: "delivery-1",
      event: "push",
      payload_sha256: Digest::SHA256.hexdigest("{}"),
      payload: {}
    }

    Github::WebhookDelivery.create!(attrs)

    duplicate = Github::WebhookDelivery.new(attrs)
    assert_not duplicate.valid?
  end

  test "retryable only applies to failed deliveries with payload" do
    delivery = Github::WebhookDelivery.new(
      account: accounts("37s"),
      delivery_id: "delivery-1",
      event: "push",
      payload_sha256: Digest::SHA256.hexdigest("{}"),
      status: "failed",
      payload: { "ref" => "refs/heads/main" }
    )

    assert delivery.retryable?

    delivery.payload = {}
    assert_not delivery.retryable?
  end
end
