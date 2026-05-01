require "test_helper"

class LegacyImports::AsanasControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
  end

  test "new is visible to admins" do
    get new_legacy_imports_asana_path

    assert_response :success
    assert_match "Import Asana Tasks", response.body
    assert_match @board.name, response.body
  end

  test "create imports Asana JSON tasks as legacy cards" do
    assert_difference -> { Card.count }, 2 do
      assert_difference -> { Card::ResolutionRecord.where(legacy_import: true).count }, 2 do
        post legacy_imports_asana_path, params: { board_id: @board.id, file: fixture_file_upload("asana_tasks.json", "application/json") }
      end
    end

    assert_response :created
    assert_match "Cards created: 2", response.body
    assert_match "Cards needing structuring: 2", response.body

    record = Card::ResolutionRecord.find_by!(legacy_source: "asana", legacy_external_id: "asana-1")
    assert_equal @board, record.card.board
    assert_equal "Imported Asana issue", record.card.title
    assert_predicate record, :gate_one_legacy?
    assert_predicate record, :needs_structuring?
  end

  test "create skips duplicate Asana tasks" do
    post legacy_imports_asana_path, params: { board_id: @board.id, file: fixture_file_upload("asana_tasks.json", "application/json") }
    assert_response :created

    assert_no_difference -> { Card.count } do
      assert_no_difference -> { Card::ResolutionRecord.count } do
        post legacy_imports_asana_path, params: { board_id: @board.id, file: fixture_file_upload("asana_tasks.json", "application/json") }
      end
    end

    assert_response :created
    assert_match "Duplicates skipped: 2", response.body
  end

  test "create rejects invalid JSON" do
    post legacy_imports_asana_path, params: { board_id: @board.id, file: fixture_file_upload("moon.jpg", "application/json") }

    assert_response :unprocessable_entity
    assert_match "Asana import failed", response.body
  end

  test "non admins cannot import" do
    logout_and_sign_in_as :david

    get new_legacy_imports_asana_path

    assert_response :forbidden
  end

  test "non admins cannot create imports" do
    logout_and_sign_in_as :david

    assert_no_difference -> { Card.count } do
      post legacy_imports_asana_path, params: { board_id: @board.id, file: fixture_file_upload("asana_tasks.json", "application/json") }
    end

    assert_response :forbidden
  end

  test "admins cannot import into another account board" do
    other_account_board = boards(:miltons_wish_list)

    assert_no_difference -> { Card.count } do
      post legacy_imports_asana_path, params: { board_id: other_account_board.id, file: fixture_file_upload("asana_tasks.json", "application/json") }
    end

    assert_response :not_found
  end
end
