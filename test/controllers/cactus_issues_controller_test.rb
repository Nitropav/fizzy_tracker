require "test_helper"

class CactusIssuesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "new renders focused issue intake form with project selector" do
    get new_cactus_issue_path

    assert_response :success
    assert_select "h1", text: "Create issue"
    assert_select "select[name='cactus_issue[board_id]']"
    assert_select "textarea[name='cactus_issue[problem_description]']"
    assert_select "button[name='cactus_issue[draft]']", text: "Save draft"
  end

  test "create makes issue in selected project with structured gate one record" do
    assert_difference -> { Card.count }, +1 do
      assert_difference -> { Card::ResolutionRecord.count }, +1 do
        post cactus_issues_path, params: {
          cactus_issue: {
            board_id: boards(:writebook).id,
            title: "Checkout total changes after refresh",
            problem_description: "The customer subtotal changes after refreshing the quote.",
            reproduction_steps: "Open quote\nRefresh page",
            expected_behavior: "Subtotal should stay the same",
            actual_behavior: "Subtotal changes",
            environment_context: "Customer portal quote screen"
          }
        }
      end
    end

    card = Card.last

    assert_redirected_to card_path(card)
    assert_equal boards(:writebook), card.board
    assert_equal "Checkout total changes after refresh", card.title
    assert card.resolution_record.gate_one_complete?
  end

  test "create keeps sparse issue in needs info state" do
    post cactus_issues_path, params: {
      cactus_issue: {
        board_id: boards(:writebook).id,
        title: "Checkout looks wrong",
        problem_description: "",
        reproduction_steps: "",
        expected_behavior: "",
        actual_behavior: "",
        environment_context: ""
      }
    }

    card = Card.last

    assert_redirected_to card_path(card)
    assert_equal "needs_info", card.cactus_workflow_state
    assert_equal %i[ problem_description reproduction_steps expected_behavior actual_behavior environment_context ],
      card.resolution_record.missing_gate_one_fields
  end

  test "create requires a project" do
    assert_no_difference -> { Card.count } do
      post cactus_issues_path, params: {
        cactus_issue: {
          board_id: "",
          title: "Checkout looks wrong",
          problem_description: "",
          reproduction_steps: "",
          expected_behavior: "",
          actual_behavior: "",
          environment_context: ""
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match "Select a project", response.body
  end

  test "create can save an empty draft issue" do
    assert_difference -> { Card.count }, +1 do
      assert_difference -> { Card::ResolutionRecord.count }, +1 do
        post cactus_issues_path, params: {
          cactus_issue: {
            board_id: boards(:writebook).id,
            draft: "true",
            title: "",
            problem_description: "",
            reproduction_steps: "",
            expected_behavior: "",
            actual_behavior: "",
            environment_context: ""
          }
        }
      end
    end

    card = Card.last

    assert_redirected_to card_path(card)
    assert card.drafted?
    assert_equal "draft", card.cactus_workflow_state
    assert_equal "Draft issue", card.title
    assert_equal "Draft issue saved.", flash[:notice]
  end
end
