require "test_helper"

class Cards::TriagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)
    original_column = card.column
    column = columns(:writebook_in_progress)

    assert_changes -> { card.reload.column }, from: original_column, to: column do
      post card_triage_path(card, column_id: column.id)
      assert_redirected_to card
    end
  end

  test "developer cannot triage issue" do
    logout_and_sign_in_as :david
    card = cards(:logo)
    original_column = card.column

    assert_no_changes -> { card.reload.column } do
      post card_triage_path(card, column_id: columns(:writebook_in_progress).id), as: :json
    end

    assert_response :forbidden
    assert_equal original_column, card.reload.column
  end

  test "create is blocked when resolution record has incomplete gate one" do
    card = cards(:buy_domain)
    column = columns(:writebook_in_progress)
    card.create_resolution_record!(problem_description: "Known problem")

    assert_no_changes -> { card.reload.column } do
      post card_triage_path(card, column_id: column.id), as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_match "Complete Gate 1", response.body
  end

  test "create as JSON reports incomplete gate one" do
    card = cards(:buy_domain)
    column = columns(:writebook_in_progress)
    card.create_resolution_record!(problem_description: "Known problem")

    post card_triage_path(card, column_id: column.id), as: :json

    assert_response :unprocessable_entity
    assert_equal [ "reproduction_steps", "expected_behavior", "actual_behavior", "environment_context" ], @response.parsed_body["missing_gate_one_fields"]
  end

  test "destroy" do
    card = cards(:shipping)

    assert_changes -> { card.reload.column }, to: nil do
      delete card_triage_path(card), as: :turbo_stream
      assert_redirected_to card
    end
  end

  test "create as JSON" do
    card = cards(:logo)
    column = columns(:writebook_in_progress)

    post card_triage_path(card, column_id: column.id), as: :json

    assert_response :no_content
    assert_equal column, card.reload.column
  end

  test "destroy as JSON" do
    card = cards(:shipping)

    assert card.column.present?

    delete card_triage_path(card), as: :json

    assert_response :no_content
    assert_nil card.reload.column
  end

  test "create cannot triage inaccessible account card" do
    other_account_card = create_other_account_card

    post card_triage_path(other_account_card, column_id: columns(:writebook_in_progress).id), as: :json

    assert_response :not_found
    assert_nil other_account_card.reload.column
  end

  private
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
