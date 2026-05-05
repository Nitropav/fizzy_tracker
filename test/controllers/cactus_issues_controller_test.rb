require "test_helper"

class CactusIssuesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "new renders focused issue intake form with project selector" do
    get new_cactus_issue_path

    assert_response :success
    assert_select "h1", text: "Create issue"
    assert_match "Gate 1 readiness", response.body
    assert_select "select[name='cactus_issue[board_id]']"
    assert_select "select[name='cactus_issue[priority]']" do
      assert_select "option", text: "Urgent"
      assert_select "option", text: "Normal"
    end
    assert_select "textarea[name='cactus_issue[problem_description]']"
    assert_select "lexxy-editor[name='cactus_issue[description]']"
    assert_select "input[type='file'][name='cactus_issue[attachments][]'][multiple='multiple']"
    assert_select "button[name='cactus_issue[draft]']", text: "Save draft"
  end

  test "create makes issue in selected project with structured gate one record" do
    assert_difference -> { Card.count }, +1 do
      assert_difference -> { Card::ResolutionRecord.count }, +1 do
        post cactus_issues_path, params: {
          cactus_issue: {
            board_id: boards(:writebook).id,
            title: "Checkout total changes after refresh",
            priority: "high",
            problem_description: "The customer subtotal changes after refreshing the quote.",
            reproduction_steps: "Open quote\nRefresh page",
            expected_behavior: "Subtotal should stay the same",
            actual_behavior: "Subtotal changes",
            environment_context: "Customer portal quote screen",
            description: "<p>Screenshot and console log attached.</p>"
          }
        }
      end
    end

    card = Card.last

    assert_redirected_to card_path(card)
    assert_equal boards(:writebook), card.board
    assert_equal "Checkout total changes after refresh", card.title
    assert_equal "Screenshot and console log attached.", card.description.to_plain_text.strip
    assert_equal "high", card.resolution_record.priority
    assert card.resolution_record.gate_one_complete?
  end

  test "create stores uploaded evidence files as issue attachments" do
    assert_difference -> { ActiveStorage::Blob.count }, +1 do
      post cactus_issues_path, params: {
        cactus_issue: {
          board_id: boards(:writebook).id,
          title: "Checkout total evidence",
          problem_description: "The customer subtotal changes after refreshing the quote.",
          reproduction_steps: "Open quote\nRefresh page",
          expected_behavior: "Subtotal should stay the same",
          actual_behavior: "Subtotal changes",
          environment_context: "Customer portal quote screen",
          attachments: [ fixture_file_upload("moon.jpg", "image/jpeg") ]
        }
      }
    end

    card = Card.last

    assert_redirected_to card_path(card)
    assert card.has_attachments?
    assert_equal "moon.jpg", card.attachments.first.filename.to_s
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
