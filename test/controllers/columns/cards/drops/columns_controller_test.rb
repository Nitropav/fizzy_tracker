require "test_helper"

class Columns::Cards::Drops::ColumnsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "create" do
    card = cards(:logo)
    column = columns(:writebook_in_progress)

    assert_changes -> { card.reload.column }, to: column do
      post columns_card_drops_column_path(card, column_id: column.id), as: :turbo_stream
      assert_response :success
    end
  end

  test "create is blocked when resolution record has incomplete gate one" do
    card = cards(:buy_domain)
    column = columns(:writebook_in_progress)
    card.create_resolution_record!(problem_description: "Known problem")

    assert_no_changes -> { card.reload.column } do
      post columns_card_drops_column_path(card, column_id: column.id), as: :turbo_stream
    end

    assert_response :unprocessable_entity
    assert_match "Complete Gate 1", response.body
  end
end
