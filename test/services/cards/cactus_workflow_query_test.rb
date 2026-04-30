require "test_helper"

class Cards::CactusWorkflowQueryTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @scope = accounts("37s").cards
    @query = Cards::CactusWorkflowQuery.new(@scope)
  end

  test "returns draft cards" do
    draft = boards(:writebook).cards.create!(creator: users(:david), status: :drafted)

    assert_includes @query.for("draft"), draft
  end

  test "returns needs info cards" do
    assert_includes @query.for("needs_info"), cards(:logo)
  end

  test "returns open cards" do
    card = cards(:buy_domain)
    card.create_resolution_record!(gate_one_attrs)

    assert_includes @query.for("open"), card
  end

  test "returns in progress cards" do
    card = cards(:text)
    card.create_resolution_record!(gate_one_attrs)

    assert_includes @query.for("in_progress"), card
  end

  test "returns needs review cards" do
    card = cards(:text)
    card.create_resolution_record!(gate_one_attrs.merge(gate_two_attrs))

    assert_includes @query.for("needs_review"), card
  end

  test "returns resolved cards" do
    assert_includes @query.for("resolved"), cards(:shipping)
  end

  test "returns closed cards with approved training examples" do
    card = cards(:shipping)
    card.training_examples.create!(
      status: :approved,
      input_context: { "card" => { "id" => card.id } },
      metadata: { "card_id" => card.id }
    )

    assert_includes @query.for("closed"), card
  end

  private
    def gate_one_attrs
      {
        problem_description: "Logo is unreadable",
        reproduction_steps: "Open the card",
        expected_behavior: "Logo should be readable",
        actual_behavior: "Logo is too small",
        environment_context: "Fizzy card page"
      }
    end

    def gate_two_attrs
      {
        root_cause: "Image sizing used the wrong max width",
        fix_summary: "Adjusted the card image layout",
        verification_steps: "Opened the card and confirmed the logo is readable"
      }
    end
end
