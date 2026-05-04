require "test_helper"

class Github::WebhookDeliveryRetriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @account = accounts("37s")
    @card = cards(:logo)
  end

  test "retry reprocesses failed delivery and links code evidence" do
    delivery = failed_delivery(
      delivery_id: "delivery-retry",
      event: "push",
      payload: {
        "ref" => "refs/heads/main",
        "repository" => { "full_name" => "cactus/fizzy_tracker" },
        "commits" => [
          {
            "id" => "abc123",
            "message" => "Fix CT-#{@card.number}",
            "url" => "https://github.com/cactus/fizzy_tracker/commit/abc123"
          }
        ]
      }
    )

    assert_difference -> { @card.code_links.count }, +1 do
      post github_webhook_delivery_retry_path(delivery)
    end

    assert_redirected_to cactus_integrations_path
    assert_equal "GitHub delivery retried. Linked 1 code references.", flash[:notice]
    assert delivery.reload.processed?
    assert_equal 1, delivery.linked_code_references_count
    assert_nil delivery.error_message
  end

  test "retry keeps delivery failed when payload is still invalid" do
    delivery = failed_delivery(
      delivery_id: "delivery-retry-fails",
      event: "push",
      payload: {
        "ref" => "refs/heads/main",
        "repository" => { "full_name" => "cactus/fizzy_tracker" },
        "commits" => [
          {
            "message" => "Fix CT-#{@card.number}",
            "url" => "https://github.com/cactus/fizzy_tracker/commit/abc123"
          }
        ]
      }
    )

    assert_no_difference -> { @card.code_links.count } do
      post github_webhook_delivery_retry_path(delivery)
    end

    assert_redirected_to cactus_integrations_path
    assert_match "GitHub delivery retry failed", flash[:alert]
    assert delivery.reload.failed?
    assert_match "Missing required GitHub payload field", delivery.error_message
  end

  test "retry rejects non failed deliveries" do
    delivery = @account.github_webhook_deliveries.create!(
      delivery_id: "delivery-processed",
      event: "push",
      status: "processed",
      payload_sha256: Digest::SHA256.hexdigest("{}"),
      payload: { "ref" => "refs/heads/main" },
      processed_at: Time.current
    )

    post github_webhook_delivery_retry_path(delivery)

    assert_redirected_to cactus_integrations_path
    assert_equal "Only failed GitHub deliveries with a saved payload can be retried.", flash[:alert]
  end

  test "retry is forbidden for non admins" do
    delivery = failed_delivery(
      delivery_id: "delivery-forbidden",
      event: "push",
      payload: { "ref" => "refs/heads/main" }
    )
    logout_and_sign_in_as :david

    post github_webhook_delivery_retry_path(delivery)

    assert_response :forbidden
  end

  private
    def failed_delivery(delivery_id:, event:, payload:)
      @account.github_webhook_deliveries.create!(
        delivery_id: delivery_id,
        event: event,
        status: "failed",
        payload_sha256: Digest::SHA256.hexdigest(payload.to_json),
        payload: payload,
        error_message: "Previous failure",
        processed_at: Time.current
      )
    end
end
