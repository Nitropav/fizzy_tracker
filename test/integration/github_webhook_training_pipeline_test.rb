require "test_helper"

class GithubWebhookTrainingPipelineTest < ActionDispatch::IntegrationTest
  setup do
    @secret = "test-secret"
    @previous_secret = ENV["GITHUB_WEBHOOK_SECRET"]
    ENV["GITHUB_WEBHOOK_SECRET"] = @secret
    sign_in_as :kevin
  end

  teardown do
    ENV["GITHUB_WEBHOOK_SECRET"] = @previous_secret
  end

  test "signed webhook evidence is visible on the card and included in training metadata" do
    card = cards(:logo)
    card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      reproduction_steps: "Open the card detail page",
      expected_behavior: "The logo should be readable",
      actual_behavior: "The logo is too small",
      environment_context: "Cactus card page in Chrome",
      structured_summary: "Logo is unreadable on the card detail page",
      priority: "high",
      category: "bug",
      domain: "ui/ux",
      severity: "cosmetic",
      root_cause: "The card image max width was too small",
      fix_summary: "Increased the card image max width and adjusted spacing",
      verification_steps: "Opened the card detail page and confirmed the logo is readable"
    )
    payload = {
      ref: "refs/heads/fix/ct-#{card.number}-logo",
      repository: { full_name: "cactus/fizzy_tracker" },
      commits: [
        {
          id: "abc123github",
          message: "Fix card logo layout for CT-#{card.number}",
          url: "https://github.com/cactus/fizzy_tracker/commit/abc123github",
          author: { name: "Developer" },
          timestamp: Time.current.iso8601
        }
      ]
    }.to_json

    assert_difference -> { Github::WebhookDelivery.count }, +1 do
      assert_difference -> { card.reload.code_links.count }, +1 do
        post github_webhook_path, params: payload, headers: github_headers(payload, event: "push", delivery_id: "delivery-training-pipeline")
      end
    end

    assert_response :accepted
    assert_equal 1, @response.parsed_body["linked_code_references"]
    assert card.reload.cactus_code_evidence_present?

    code_link = card.code_links.last
    assert_equal "commit", code_link.external_type
    assert_equal "abc123github", code_link.sha
    assert_equal "cactus/fizzy_tracker", code_link.repository

    get card_path(card)

    assert_response :success
    assert_match "Code evidence", response.body
    assert_match "Fix card logo layout", response.body
    assert_select "a[href=?]", "https://github.com/cactus/fizzy_tracker/commit/abc123github", text: "Open"

    training_example = TrainingExamples::Generator.new(card).generate

    assert_equal [ "abc123github" ], training_example.metadata["commit_shas"]
    assert_equal [ code_link.id ], training_example.metadata["code_link_ids"]
    assert_equal true, training_example.metadata["code_evidence_present"]
    assert_equal "abc123github", training_example.input_context.dig("code_links", 0, "sha")
    assert_equal "push", training_example.input_context.dig("code_links", 0, "metadata", "github_event")
  end

  private
    def github_headers(payload, event:, delivery_id:)
      {
        "CONTENT_TYPE" => "application/json",
        "X-GitHub-Event" => event,
        "X-GitHub-Delivery" => delivery_id,
        "X-Hub-Signature-256" => "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', @secret, payload)}"
      }
    end
end
