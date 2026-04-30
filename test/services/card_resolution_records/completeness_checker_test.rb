require "test_helper"

class CardResolutionRecords::CompletenessCheckerTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @record = cards(:logo).create_resolution_record!(
      problem_description: "Card image is too small",
      reproduction_steps: "Open the board and inspect the logo card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small",
      environment_context: "Fizzy card detail page",
      root_cause: "Image sizing used the wrong max width",
      fix_summary: "Adjusted the card image layout",
      verification_steps: "Opened the card and confirmed the logo is readable",
      linked_commit_shas: [ "abc123" ]
    )
  end

  test "reports structured gate completeness" do
    result = CardResolutionRecords::CompletenessChecker.new(@record).check

    assert result.gate_one_complete
    assert result.gate_two_complete
    assert_empty result.missing_gate_one_fields
    assert_empty result.missing_gate_two_fields
    assert result.code_evidence_present
  end
end
