require "test_helper"

class CardResolutionRecords::GateOneGuidanceTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @card = cards(:logo)
  end

  test "returns all gate one prompts when no reporter fields are present" do
    guidance = CardResolutionRecords::GateOneGuidance.new(@card)

    assert_not guidance.complete?
    assert_equal Card::ResolutionRecord::GATE_ONE_REQUIRED_FIELDS, guidance.missing_items.map(&:field)
    assert_equal :problem_description, guidance.next_item.field
    assert_includes guidance.next_item.prompt, "Describe the issue"
  end

  test "returns only missing prompts for a partial resolution record" do
    @card.create_resolution_record!(
      problem_description: "Card image is unreadable",
      reproduction_steps: "Open the card detail page",
      expected_behavior: "Image should be readable"
    )

    guidance = CardResolutionRecords::GateOneGuidance.new(@card)

    assert_equal %i[ actual_behavior environment_context ], guidance.missing_items.map(&:field)
    assert_equal "Actual behavior", guidance.next_item.label
  end

  test "is complete when required reporter fields are present" do
    @card.create_resolution_record!(
      problem_description: "Card image is unreadable",
      reproduction_steps: "Open the card detail page",
      expected_behavior: "Image should be readable",
      actual_behavior: "Image is too small",
      environment_context: "Fizzy card page"
    )

    guidance = CardResolutionRecords::GateOneGuidance.new(@card)

    assert guidance.complete?
    assert_empty guidance.missing_items
    assert_nil guidance.next_item
  end
end
