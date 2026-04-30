require "test_helper"

class Card::CodeLinkTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @card = cards(:logo)
  end

  test "defaults account from card" do
    code_link = @card.code_links.create!(
      provider: "github",
      external_type: "commit",
      external_id: "abc123",
      sha: "abc123",
      metadata: { "repository" => "cactus/fizzy" }
    )

    assert_equal @card.account, code_link.account
  end

  test "requires account to match card account" do
    code_link = Card::CodeLink.new(
      account: accounts(:initech),
      card: @card,
      provider: "github",
      external_type: "commit",
      external_id: "abc123",
      metadata: {}
    )

    assert_not code_link.valid?
    assert_includes code_link.errors[:account], "must match the card account"
  end

  test "requires known provider and external type" do
    code_link = @card.code_links.build(
      provider: "gitlab",
      external_type: "issue",
      external_id: "1",
      metadata: {}
    )

    assert_not code_link.valid?
    assert code_link.errors[:provider].present?
    assert code_link.errors[:external_type].present?
  end
end
