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
      environment_context: "Account settings"
    )

    get cactus_queues_path(state: "open")

    assert_response :success
    assert_select "form[action=?][method=?]", card_triage_path(cards(:buy_domain)), "post"
    assert_select "select[name='column_id']"
    assert_select "option", text: "Triage"
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
    assert_select "a[href*=?]", "#resolution_record_card_#{card.id}", text: "Fill resolution"
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
    assert_select "a[href*=?]", "#resolution_record_card_#{card.id}", text: "Review resolution"
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
end
