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

  test "create is blocked before issue is in review state" do
    card = cards(:buy_domain)
    card.create_resolution_record!(resolution_record_attrs)

    assert_no_difference -> { card.training_examples.count } do
      post card_resolution_path(card), as: :json
    end

    assert_response :unprocessable_entity
    assert_match "Move this issue into active work", @response.parsed_body["error"]
    assert_not card.reload.closed?
  end

  test "create is blocked when code evidence is missing" do
    card = cards(:logo)
    attrs = resolution_record_attrs.except(:linked_commit_shas)
    card.create_resolution_record!(attrs)

    assert_no_difference -> { card.training_examples.count } do
      post card_resolution_path(card), as: :json
    end

    assert_response :unprocessable_entity
    assert_match "Add code evidence", @response.parsed_body["error"]
    assert_equal false, @response.parsed_body["code_evidence_present"]
    assert_not card.reload.closed?
  end

  test "create accepts github code links as code evidence" do
    card = cards(:logo)
    attrs = resolution_record_attrs.except(:linked_commit_shas)
    card.create_resolution_record!(attrs)
    card.code_links.create!(
      account: card.account,
      provider: "github",
      external_type: "commit",
      external_id: "abc123",
      sha: "abc123",
      title: "Fix CT-#{card.number}",
      url: "https://github.com/cactus/fizzy_tracker/commit/abc123",
      metadata: {}
    )

    assert_difference -> { card.training_examples.count }, +1 do
      post card_resolution_path(card), as: :json
    end

    assert_response :created
    assert card.reload.closed?
  end

  test "create cannot resolve inaccessible account card" do
    other_account_card = create_other_account_card

    assert_no_difference -> { TrainingExample.count } do
      post card_resolution_path(other_account_card), as: :json
    end

    assert_response :not_found
    assert_not other_account_card.reload.closed?
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
        verification_steps: "Opened the card and confirmed the logo is readable",
        linked_commit_shas: [ "abc123" ]
      }
    end

    def create_other_account_card
      Current.with(account: accounts(:initech), session: sessions(:mike)) do
        boards(:miltons_wish_list).cards.create!(
          account: accounts(:initech),
          creator: users(:mike),
          status: :published,
          number: 999,
          title: "Other account card"
        )
      end
    end
end
