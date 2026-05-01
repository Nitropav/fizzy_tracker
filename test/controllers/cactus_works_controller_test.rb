require "test_helper"

class CactusWorksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get cactus_work_path

    assert_response :success
    assert_match "My Work", response.body
    assert_match "Assigned Active Issues", response.body
    assert_select "a", text: "#1 The logo isn't big enough"
  end

  test "show lists assigned issues needing gate two" do
    card = cards(:text)
    card.assignments.create!(assignee: users(:kevin), assigner: users(:david), account: accounts(:"37s"))
    card.create_resolution_record!(
      problem_description: "Text is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Text should be readable",
      actual_behavior: "Text is too small",
      environment_context: "Card detail page",
      root_cause: "Wrong font scale"
    )

    get cactus_work_path

    assert_response :success
    assert_match "Needs Gate 2", response.body
    assert_match "The text is too small", response.body
    assert_match "fix summary", response.body
    assert_match "verification steps", response.body
    assert_select "a[href=?]", edit_card_resolution_record_path(card), text: "Fill Gate 2"
  end

  test "show lists unassigned ready issues to claim" do
    card = cards(:buy_domain)
    card.update!(column: columns(:writebook_in_progress))
    card.create_resolution_record!(
      problem_description: "Shipping is blocked",
      reproduction_steps: "Open release screen",
      expected_behavior: "Can ship",
      actual_behavior: "Ship button is disabled",
      environment_context: "Release workflow"
    )

    get cactus_work_path

    assert_response :success
    assert_match "Ready To Claim", response.body
    assert_select "a", text: "#5 Buy domain"
    assert_select "form[action=?][method=?]", card_self_assignment_path(card), "post" do
      assert_select "button", text: "Claim"
    end
  end

  test "show lists assigned issues ready for review" do
    card = cards(:text)
    card.assignments.create!(assignee: users(:kevin), assigner: users(:david), account: accounts(:"37s"))
    card.create_resolution_record!(
      problem_description: "Text is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Text should be readable",
      actual_behavior: "Text is too small",
      environment_context: "Card detail page",
      root_cause: "Wrong font scale",
      fix_summary: "Adjusted CSS scale",
      verification_steps: "Opened the card and verified text size"
    )

    get cactus_work_path

    assert_response :success
    assert_match "Needs Review", response.body
    assert_select "a[href=?]", edit_card_resolution_record_path(card), text: "Review"
    assert_select "form[action=?][method=?]", card_resolution_path(card), "post" do
      assert_select "button", text: "Mark resolved"
    end
  end
end
