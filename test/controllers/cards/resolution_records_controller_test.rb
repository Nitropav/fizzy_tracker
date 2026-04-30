require "test_helper"

class Cards::ResolutionRecordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @card = cards(:logo)
  end

  test "update creates resolution record for card" do
    assert_difference -> { Card::ResolutionRecord.count }, +1 do
      put card_resolution_record_path(@card), params: {
        card_resolution_record: {
          problem_description: "Logo is unreadable",
          reproduction_steps: "Open the card",
          expected_behavior: "Logo should be readable",
          actual_behavior: "Logo is too small",
          environment_context: "Fizzy card page"
        }
      }, as: :turbo_stream
    end

    assert_response :success
    assert @card.reload.resolution_record.gate_one_complete?
  end

  test "update modifies existing resolution record" do
    record = @card.create_resolution_record!(problem_description: "Old problem")

    put card_resolution_record_path(@card), params: {
      card_resolution_record: {
        problem_description: "Updated problem",
        reproduction_steps: "Open the card",
        expected_behavior: "Logo should be readable",
        actual_behavior: "Logo is too small",
        environment_context: "Fizzy card page",
        linked_commit_shas: [ "abc123, def456" ]
      }
    }, as: :json

    assert_response :success
    assert_equal "Updated problem", record.reload.problem_description
    assert_equal [ "abc123", "def456" ], record.linked_commit_shas
  end
end
