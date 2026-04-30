require "test_helper"

class Cards::ResolutionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create resolves card and generates training example" do
    card = cards(:logo)
    card.create_resolution_record!(resolution_record_attrs)

    assert_difference -> { card.training_examples.count }, +1 do
      post card_resolution_path(card), as: :turbo_stream
    end

    assert_response :success
    assert card.reload.closed?
    assert card.training_examples.last.pending_review?
  end

  test "create as json returns workflow state and training example id" do
    card = cards(:logo)
    card.create_resolution_record!(resolution_record_attrs)

    post card_resolution_path(card), as: :json

    assert_response :created
    assert_equal "resolved", @response.parsed_body["cactus_workflow_state"]
    assert_equal card.training_examples.last.id, @response.parsed_body["training_example_id"]
  end

  test "create is blocked when gate two is incomplete" do
    card = cards(:logo)
    card.create_resolution_record!(root_cause: "Known cause")

    assert_no_difference -> { card.training_examples.count } do
      post card_resolution_path(card), as: :json
    end

    assert_response :unprocessable_entity
    assert_match "Complete Gate 2", @response.parsed_body["error"]
  end

  private
    def resolution_record_attrs
      {
        problem_description: "Logo is unreadable",
        reproduction_steps: "Open the card",
        expected_behavior: "Logo should be readable",
        actual_behavior: "Logo is too small",
        environment_context: "Fizzy card page",
        root_cause: "Image sizing used the wrong max width",
        fix_summary: "Adjusted the card image layout",
        verification_steps: "Opened the card and confirmed the logo is readable"
      }
    end
end
