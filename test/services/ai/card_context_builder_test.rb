require "test_helper"

class Ai::CardContextBuilderTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @card = cards(:logo)
    @card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small",
      environment_context: "Fizzy card page",
      root_cause: "Image sizing used the wrong max width",
      fix_summary: "Adjusted the card image layout",
      verification_steps: "Opened the card and confirmed the logo is readable",
      category: "bug",
      domain: "ui",
      severity: "cosmetic",
      linked_commit_shas: [ "abc123" ],
      legacy_import: true,
      legacy_source: "asana",
      legacy_external_id: "1200",
      legacy_imported_at: Time.current,
      legacy_metadata: { "permalink_url" => "https://app.asana.com/0/1/1200" },
      gate_one_legacy: true,
      needs_structuring: false
    )
    @card.code_links.create!(
      provider: "github",
      external_type: "pull_request",
      external_id: "42",
      repository: "cactus/fizzy_tracker",
      sha: "def456",
      title: "Fix logo",
      url: "https://github.com/cactus/fizzy_tracker/pull/42",
      metadata: { "action" => "opened" }
    )
  end

  test "builds structured card context" do
    context = Ai::CardContextBuilder.new(@card).build

    assert_equal @card.id, context.dig("card", "id")
    assert_equal @card.number, context.dig("card", "number")
    assert_equal "The logo isn't big enough", context.dig("card", "title")
    assert_equal "needs_review", context.dig("card", "cactus_workflow_state")
    assert_equal "37signals", context.dig("account", "name")
    assert_equal "Writebook", context.dig("board", "name")
    assert_equal "Triage", context.dig("column", "name")
    assert_equal [ "jz", "kevin" ], context["assignees"].map { it["name"].downcase }.sort
    assert_includes context["tags"].map { it["title"] }, "web"
    assert_includes context["comments"].map { it["body"] }, "I agree."
    assert_includes context["events"].map { it["action"] }, "card_published"
    assert_equal "complete", context.dig("resolution_record", "gate_one_status")
    assert_equal "complete", context.dig("resolution_record", "gate_two_status")
    assert_equal [ "abc123" ], context.dig("resolution_record", "linked_commit_shas")
    assert_equal true, context.dig("resolution_record", "legacy_import")
    assert_equal "asana", context.dig("resolution_record", "legacy_source")
    assert_equal "1200", context.dig("resolution_record", "legacy_external_id")
    assert_equal true, context.dig("resolution_record", "gate_one_legacy")
    assert_equal false, context.dig("resolution_record", "needs_structuring")
    assert_equal [ "pull_request" ], context["code_links"].map { it["external_type"] }
    assert_equal "https://github.com/cactus/fizzy_tracker/pull/42", context.dig("code_links", 0, "url")
    assert_equal true, context.dig("resolution_record", "code_evidence_present")
  end

  test "returns nil resolution payload when card has no resolution record" do
    context = Ai::CardContextBuilder.new(cards(:text)).build

    assert_nil context["resolution_record"]
  end
end
