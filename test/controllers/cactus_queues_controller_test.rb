require "test_helper"

class CactusQueuesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    get cactus_queues_path

    assert_response :success
    assert_match "Cactus Queue", response.body
    assert_match "The logo", response.body
  end

  test "index paginates large queues" do
    board = boards(:writebook)

    with_current_user :kevin do
      60.times do |index|
        board.cards.create!(
          account: board.account,
          creator: users(:kevin),
          status: :published,
          title: "Bulk queue issue #{index}",
          description: "Bulk queue issue #{index}"
        )
      end
    end

    get cactus_queues_path

    assert_response :success
    assert_select ".pagination-link"
  end

  test "index filters by workflow state" do
    get cactus_queues_path(state: "needs_info")

    assert_response :success
    assert_match "Needs info", response.body
  end

  test "needs info queue shows next reporter question" do
    cards(:logo).create_resolution_record!(problem_description: "Logo is unreadable")

    get cactus_queues_path(state: "needs_info")

    assert_response :success
    assert_match "Ask:", response.body
    assert_match "Reproduction steps", response.body
    assert_match "List the exact steps needed to reproduce it", response.body
  end

  test "open queue shows inline triage form" do
    cards(:buy_domain).create_resolution_record!(
      problem_description: "Domain purchase is blocked",
      reproduction_steps: "Open settings",
      expected_behavior: "Domain can be purchased",
      actual_behavior: "Purchase button is disabled",
      environment_context: "Account settings",
      priority: "urgent"
    )

    get cactus_queues_path(state: "open")

    assert_response :success
    assert_match "Priority: Urgent", response.body
    assert_select "##{ActionView::RecordIdentifier.dom_id(cards(:buy_domain), :cactus_queue)}"
    assert_select "a[href=?][data-turbo-frame=?]", card_path(cards(:buy_domain)), "_top"
    assert_select "form[action=?][method=?]", card_triage_path(cards(:buy_domain)), "post"
    assert_select "input[name='return_to'][value='cactus_queue']", visible: false
    assert_select "input[name='queue_state'][value='open']", visible: false
    assert_select "select[name='column_id']"
    assert_select "option", text: "Triage"
    assert_select "form[action=?][method=?]", card_resolution_record_path(cards(:buy_domain)), "post" do
      assert_select "select[name='card_resolution_record[priority]']" do
        assert_select "option", text: "Urgent"
        assert_select "option", text: "Normal"
      end
      assert_select "select[name='card_resolution_record[category]']" do
        assert_select "option", text: "Bug"
        assert_select "option", text: "Feature request"
      end
      assert_select "select[name='card_resolution_record[domain]']" do
        assert_select "option", text: "Assembly config"
        assert_select "option", text: "Pricing"
      end
      assert_select "select[name='card_resolution_record[severity]']" do
        assert_select "option", text: "Blocks ordering"
        assert_select "option", text: "Degrades experience"
      end
      assert_select "input[name='return_to'][value='cactus_queue']", visible: false
      assert_select "input[type='submit'][value='Save classification']"
    end
  end

  test "open queue links to column setup when board has no columns" do
    boards(:writebook).columns.destroy_all
    cards(:buy_domain).create_resolution_record!(
      problem_description: "Domain purchase is blocked",
      reproduction_steps: "Open settings",
      expected_behavior: "Domain can be purchased",
      actual_behavior: "Purchase button is disabled",
      environment_context: "Account settings"
    )

    get cactus_queues_path(state: "open")

    assert_response :success
    assert_match "No project columns configured.", response.body
    assert_select "a[href=?][data-turbo-frame=?]", new_board_column_path(boards(:writebook)), "_top", text: "Create project column"
    assert_select "form[action=?][method=?]", card_triage_path(cards(:buy_domain)), "post", count: 0
  end

  test "in progress queue shows missing developer gate fields" do
    card = cards(:text)
    card.create_resolution_record!(
      problem_description: "Text is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Text should be readable",
      actual_behavior: "Text is too small",
      environment_context: "Card detail page",
      root_cause: "Wrong font scale"
    )

    get cactus_queues_path(state: "in_progress")

    assert_response :success
    assert_match "Complete Gate 2", response.body
    assert_match "fix summary", response.body
    assert_match "verification steps", response.body
    assert_match "Assigned to:", response.body
    assert_select "form[action=?][method=?]", card_self_assignment_path(card), "post" do
      assert_select "button", text: "Claim"
      assert_select "input[name='return_to'][value='cactus_queue']", visible: false
      assert_select "input[name='queue_state'][value='in_progress']", visible: false
    end
    assert_select "a[href=?][data-turbo-frame=?]", edit_card_resolution_record_path(card), "_top", text: "Fill resolution"
    assert_select "form[action=?][method=?]", card_assignments_path(card), "post" do
      assert_select "select[name='assignee_id']"
      assert_select "option", text: "David"
      assert_select "input[type='submit'][value='Assign']"
    end
  end

  test "needs review queue shows mark resolved action" do
    card = cards(:text)
    card.create_resolution_record!(
      problem_description: "Text is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Text should be readable",
      actual_behavior: "Text is too small",
      environment_context: "Card detail page",
      root_cause: "Wrong font scale",
      fix_summary: "Adjusted the font scale",
      verification_steps: "Opened the card and confirmed the text is readable"
    )

    get cactus_queues_path(state: "needs_review")

    assert_response :success
    assert_select "a[href=?][data-turbo-frame=?]", edit_card_resolution_record_path(card), "_top", text: "Review resolution"
    assert_select "form[action=?][method=?]", card_resolution_path(card), "post" do
      assert_select "button", text: "Mark resolved"
    end
  end

  test "users only see accessible cards" do
    logout_and_sign_in_as :mike
    integration_session.default_url_options[:script_name] = accounts(:initech).slug

    get cactus_queues_path

    assert_response :success
    assert_match "I want to play my radio", response.body
    assert_no_match "The logo", response.body
  end

  test "support users can access queue" do
    logout_and_sign_in_as :jz

    get cactus_queues_path

    assert_response :success
    assert_match "Cactus Queue", response.body
  end

  test "reporters cannot access queue" do
    users(:david).update!(cactus_role: :reporter)
    logout_and_sign_in_as :david

    get cactus_queues_path

    assert_response :forbidden
    assert_match "Access denied", response.body
  end
end
