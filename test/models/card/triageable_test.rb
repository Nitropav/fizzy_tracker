require "test_helper"

class Card::TriageableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "active cards with columns are triaged" do
    assert cards(:logo).triaged?
    assert cards(:text).triaged?
    assert_not cards(:buy_domain).triaged?
  end

  test "active cards without columns are awaiting triage" do
    assert cards(:buy_domain).awaiting_triage?
    assert_not cards(:logo).awaiting_triage?
    assert_not cards(:text).awaiting_triage?
  end

  test "triage a card" do
    card = cards(:buy_domain)
    column = columns(:writebook_in_progress)

    assert_nil card.column
    assert card.awaiting_triage?

    assert_difference -> { card.reload.events.where(action: "card_triaged").count }, +1 do
      card.triage_into(column)
    end

    assert_equal column, card.reload.column
    assert card.triaged?
  end

  test "triage cards without a resolution record remains allowed" do
    card = cards(:buy_domain)
    column = columns(:writebook_in_progress)

    assert_nil card.resolution_record

    card.triage_into(column)

    assert_equal column, card.reload.column
  end

  test "triage is blocked when resolution record has incomplete gate one" do
    card = cards(:buy_domain)
    column = columns(:writebook_in_progress)
    card.create_resolution_record!(problem_description: "Known problem")

    error = assert_raises Card::Triageable::GateOneIncomplete do
      card.triage_into(column)
    end

    assert_match "Complete Gate 1", error.message
    assert_nil card.reload.column
  end

  test "triage is allowed when resolution record has complete gate one" do
    card = cards(:buy_domain)
    column = columns(:writebook_in_progress)
    card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small",
      environment_context: "Fizzy card page"
    )

    card.triage_into(column)

    assert_equal column, card.reload.column
  end

  test "cannot triage into a column from a different board" do
    card = cards(:buy_domain)
    other_board_column = Column.create!(
      name: "Other",
      color: "#000000",
      board: boards(:private)
    )

    assert_raises(RuntimeError, "The column must belong to the card board") do
      card.triage_into(other_board_column)
    end
  end

  test "send a card back to triage" do
    card = cards(:logo)
    assert card.triaged?

    assert_difference -> { card.reload.events.where(action: "card_sent_back_to_triage").count }, +1 do
      card.send_back_to_triage
    end

    assert card.reload.awaiting_triage?
  end

  test "scopes" do
    assert_includes Card.awaiting_triage, cards(:buy_domain)
    assert_not_includes Card.awaiting_triage, cards(:logo)
    assert_not_includes Card.awaiting_triage, cards(:text)

    assert_includes Card.triaged, cards(:logo)
    assert_includes Card.triaged, cards(:text)
    assert_not_includes Card.triaged, cards(:buy_domain)
  end
end
