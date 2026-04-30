require "test_helper"

class Github::WebhookProcessorTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @account = accounts("37s")
    @card = cards(:logo)
  end

  test "links push commits to referenced cards" do
    payload = {
      "ref" => "refs/heads/fix-logo",
      "repository" => { "full_name" => "cactus/fizzy_tracker" },
      "commits" => [
        {
          "id" => "abc123",
          "message" => "Fix logo sizing for CT-#{@card.number}",
          "url" => "https://github.com/cactus/fizzy_tracker/commit/abc123",
          "author" => { "name" => "Dev" },
          "timestamp" => Time.current.iso8601
        }
      ]
    }

    assert_difference -> { @card.code_links.count }, +1 do
      Github::WebhookProcessor.new(account: @account, event: "push", payload: payload).process
    end

    code_link = @card.code_links.last
    assert_equal "github", code_link.provider
    assert_equal "commit", code_link.external_type
    assert_equal "abc123", code_link.sha
    assert_equal "cactus/fizzy_tracker", code_link.repository
  end

  test "is idempotent for repeated commit deliveries" do
    payload = {
      "ref" => "refs/heads/fix-logo",
      "repository" => { "full_name" => "cactus/fizzy_tracker" },
      "commits" => [
        {
          "id" => "abc123",
          "message" => "Fix logo sizing for CT-#{@card.number}",
          "url" => "https://github.com/cactus/fizzy_tracker/commit/abc123"
        }
      ]
    }

    2.times { Github::WebhookProcessor.new(account: @account, event: "push", payload: payload).process }

    assert_equal 1, @card.code_links.where(external_type: "commit", external_id: "abc123").count
  end

  test "links pull requests to referenced cards" do
    payload = {
      "action" => "opened",
      "repository" => { "full_name" => "cactus/fizzy_tracker" },
      "pull_request" => {
        "number" => 42,
        "title" => "Resolve CT-#{@card.number}",
        "body" => "Fixes the broken logo",
        "html_url" => "https://github.com/cactus/fizzy_tracker/pull/42",
        "state" => "open",
        "head" => { "ref" => "fix-logo", "sha" => "def456" }
      }
    }

    assert_difference -> { @card.code_links.count }, +1 do
      Github::WebhookProcessor.new(account: @account, event: "pull_request", payload: payload).process
    end

    code_link = @card.code_links.last
    assert_equal "pull_request", code_link.external_type
    assert_equal "42", code_link.external_id
    assert_equal "https://github.com/cactus/fizzy_tracker/pull/42", code_link.url
  end

  test "ignores unsupported events" do
    assert_empty Github::WebhookProcessor.new(account: @account, event: "issues", payload: {}).process
  end
end
