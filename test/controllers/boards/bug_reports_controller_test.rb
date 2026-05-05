require "test_helper"

class Boards::BugReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
  end

  test "new renders guided bug report form" do
    get new_board_bug_report_path(@board)

    assert_response :success
    assert_select "h1", text: "Report a bug"
    assert_match "Gate 1 readiness", response.body
    assert_select "select[name='bug_report[priority]']" do
      assert_select "option", text: "Urgent"
      assert_select "option", text: "Normal"
    end
    assert_select "textarea[name='bug_report[problem_description]']"
    assert_select "lexxy-editor[name='bug_report[description]']"
    assert_select "input[type='file'][name='bug_report[attachments][]'][multiple='multiple']"
  end

  test "create makes published card with structured gate one record" do
    assert_difference -> { Card.count }, +1 do
      assert_difference -> { Card::ResolutionRecord.count }, +1 do
        post board_bug_report_path(@board), params: {
          bug_report: {
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
    record = card.resolution_record

    assert_redirected_to card_path(card)
    assert card.published?
    assert_equal @board, card.board
    assert_equal "Checkout total changes after refresh", card.title
    assert_equal "The customer subtotal changes after refreshing the quote.", card.description.to_plain_text
    assert record.gate_one_complete?
    assert_equal "Customer portal quote screen", record.environment_context
  end

  test "create stores uploaded evidence files as issue attachments" do
    assert_difference -> { ActiveStorage::Blob.count }, +1 do
      post board_bug_report_path(@board), params: {
        bug_report: {
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

  test "create keeps partial report in needs info state" do
    post board_bug_report_path(@board), params: {
      bug_report: {
        title: "Missing glass label",
        priority: "urgent",
        problem_description: "A glass label is missing on the order preview.",
        description: "<p>Preview screenshot attached.</p>"
      }
    }

    card = Card.last

    assert_redirected_to card_path(card)
    assert_equal "needs_info", card.cactus_workflow_state
    assert_equal "Preview screenshot attached.", card.description.to_plain_text.strip
    assert_equal "urgent", card.resolution_record.priority
    assert_equal %i[ reproduction_steps expected_behavior actual_behavior environment_context ], card.resolution_record.missing_gate_one_fields
  end

  test "create allows sparse report with title only" do
    assert_difference -> { Card.count }, +1 do
      assert_difference -> { Card::ResolutionRecord.count }, +1 do
        post board_bug_report_path(@board), params: {
          bug_report: {
            title: "Checkout looks wrong",
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
    assert_equal "needs_info", card.cactus_workflow_state
    assert_equal "Checkout looks wrong", card.title
    assert_equal "Checkout looks wrong", card.description.to_plain_text
    assert_equal %i[ problem_description reproduction_steps expected_behavior actual_behavior environment_context ],
      card.resolution_record.missing_gate_one_fields
  end

  test "create requires at least one report detail" do
    assert_no_difference -> { Card.count } do
      assert_no_difference -> { Card::ResolutionRecord.count } do
        post board_bug_report_path(@board), params: {
          bug_report: {
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

    assert_response :unprocessable_entity
    assert_match "Add a title or at least one issue detail", response.body
  end

  test "board show links to guided bug report form" do
    get board_path(@board)

    assert_response :success
    assert_select "a[href=?]", new_board_bug_report_path(@board), text: /New issue/
  end
end
