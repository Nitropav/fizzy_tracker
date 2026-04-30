require "test_helper"

class Cards::PublishesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)
    card.drafted!

    assert_changes -> { card.reload.published? }, from: false, to: true do
      post card_publish_path(card)
    end

    assert_redirected_to card.board
  end

  test "create seeds structured intake record" do
    card = cards(:logo)
    card.update_column :title, "Checkout price is wrong"
    card.update!(description: "Total changes after refresh.")
    card.drafted!

    assert_difference -> { Card::ResolutionRecord.count }, +1 do
      post card_publish_path(card)
    end

    record = card.reload.resolution_record
    assert_includes record.problem_description, "Checkout price is wrong"
    assert_includes record.problem_description, "Total changes after refresh."
    assert_not record.gate_one_complete?
  end

  test "create as JSON" do
    card = cards(:logo)
    card.drafted!

    assert_changes -> { card.reload.published? }, from: false, to: true do
      post card_publish_path(card), as: :json
    end

    assert_response :created
  end

  test "create and add another" do
    card = cards(:logo)
    card.drafted!

    assert_changes -> { card.reload.published? }, from: false, to: true do
      assert_difference -> { Card.count }, +1 do
        post card_publish_path(card, creation_type: "add_another")
      end
    end

    new_card = Card.last
    assert new_card.drafted?
    assert_redirected_to card_draft_path(new_card)
  end
end
