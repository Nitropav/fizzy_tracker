require "test_helper"

class Cards::GateOneAnswersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @card = cards(:logo)
  end

  test "update fills one allowed gate one field" do
    record = @card.create_resolution_record!(problem_description: "Logo is unreadable")

    patch card_gate_one_answer_path(@card), params: {
      gate_one_answer: {
        field: "reproduction_steps",
        value: "Open the card detail page"
      }
    }, as: :json

    assert_response :success
    assert_equal "Open the card detail page", record.reload.reproduction_steps
    assert_equal "needs_info", response.parsed_body["cactus_workflow_state"]
    assert_equal %i[ expected_behavior actual_behavior environment_context ], record.missing_gate_one_fields
  end

  test "update creates resolution record when missing" do
    assert_difference -> { Card::ResolutionRecord.count }, +1 do
      patch card_gate_one_answer_path(@card), params: {
        gate_one_answer: {
          field: "problem_description",
          value: "Logo is unreadable"
        }
      }
    end

    assert_redirected_to @card
    assert_equal "Logo is unreadable", @card.reload.resolution_record.problem_description
  end

  test "update strips answer value" do
    record = @card.create_resolution_record!(problem_description: "Logo is unreadable")

    patch card_gate_one_answer_path(@card), params: {
      gate_one_answer: {
        field: "expected_behavior",
        value: "  Logo should be readable  "
      }
    }, as: :json

    assert_response :success
    assert_equal "Logo should be readable", record.reload.expected_behavior
  end

  test "update rejects non gate one field" do
    @card.create_resolution_record!(problem_description: "Logo is unreadable")

    assert_raises(ActionController::BadRequest) do
      without_action_dispatch_exception_handling do
        patch card_gate_one_answer_path(@card), params: {
          gate_one_answer: {
            field: "root_cause",
            value: "Wrong image sizing"
          }
        }
      end
    end

    assert_nil @card.reload.resolution_record.root_cause
  end

  test "update can complete gate one one field at a time" do
    @card.update_column :column_id, nil
    record = @card.create_resolution_record!(problem_description: "Logo is unreadable")

    {
      reproduction_steps: "Open the card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small",
      environment_context: "Fizzy card page"
    }.each do |field, value|
      patch card_gate_one_answer_path(@card), params: {
        gate_one_answer: {
          field: field,
          value: value
        }
      }, as: :json

      assert_response :success
    end

    assert record.reload.gate_one_complete?
    assert_equal "open", @card.reload.cactus_workflow_state
  end

  test "update returns open state when gate one becomes complete" do
    @card.update_column :column_id, nil
    record = @card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small"
    )

    patch card_gate_one_answer_path(@card), params: {
      gate_one_answer: {
        field: "environment_context",
        value: "Fizzy card page"
      }
    }, as: :json

    assert_response :success
    assert record.reload.gate_one_complete?
    assert_equal "open", response.parsed_body["cactus_workflow_state"]
    assert_empty response.parsed_body["missing_gate_one_fields"]
  end
end
