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
    assert_select "form[action=?][method=?]", legacy_imports_asana_path, "post"
  end

  test "post import path opens form on refresh" do
    get legacy_imports_asana_path

    assert_response :success
    assert_match "Import Asana Tasks", response.body
    assert_match @board.name, response.body
  end

  test "create queues Asana import" do
    assert_enqueued_with(job: LegacyImports::AsanaImportJob) do
      assert_difference -> { LegacyImports::AsanaImport.count }, +1 do
        assert_no_difference -> { Card.count } do
          post legacy_imports_asana_path, params: { board_id: @board.id, file: fixture_file_upload("asana_tasks.json", "application/json") }
        end
      end
    end

    asana_import = LegacyImports::AsanaImport.latest_first.first
    assert_redirected_to legacy_imports_asana_import_path(asana_import)
    assert_predicate asana_import, :pending?
    assert_predicate asana_import.file, :attached?
  end

  test "create imports Asana JSON tasks as legacy issues in background" do
    assert_difference -> { Card.count }, 2 do
      assert_difference -> { Card::ResolutionRecord.where(legacy_import: true).count }, 2 do
        perform_enqueued_jobs do
          post legacy_imports_asana_path, params: { board_id: @board.id, file: fixture_file_upload("asana_tasks.json", "application/json") }
        end
      end
    end

    asana_import = LegacyImports::AsanaImport.latest_first.first
    assert_redirected_to legacy_imports_asana_import_path(asana_import)
    assert_predicate asana_import.reload, :completed?
    assert_equal 2, asana_import.total_count
    assert_equal 2, asana_import.created_count
    assert_equal 0, asana_import.skipped_count
    assert_equal 2, asana_import.needs_structuring_count

    record = Card::ResolutionRecord.find_by!(legacy_source: "asana", legacy_external_id: "asana-1")
    assert_equal @board, record.card.board
    assert_equal "Imported Asana issue", record.card.title
    assert_predicate record, :gate_one_legacy?
    assert_predicate record, :needs_structuring?
    assert_equal "Reporter added screenshot context", record.legacy_metadata.dig("stories", 0, "text")
    assert_equal "image.png", record.legacy_metadata.dig("attachments", 0, "name")
  end

  test "create skips duplicate Asana tasks" do
    perform_enqueued_jobs do
      post legacy_imports_asana_path, params: { board_id: @board.id, file: fixture_file_upload("asana_tasks.json", "application/json") }
    end
    assert_predicate LegacyImports::AsanaImport.latest_first.first.reload, :completed?

    assert_no_difference -> { Card.count } do
      assert_no_difference -> { Card::ResolutionRecord.count } do
        perform_enqueued_jobs do
          post legacy_imports_asana_path, params: { board_id: @board.id, file: fixture_file_upload("asana_tasks.json", "application/json") }
        end
      end
    end

    asana_import = LegacyImports::AsanaImport.latest_first.first
    assert_predicate asana_import.reload, :completed?
    assert_equal 2, asana_import.total_count
    assert_equal 0, asana_import.created_count
    assert_equal 2, asana_import.skipped_count
  end

  test "invalid JSON marks queued import as failed" do
    perform_enqueued_jobs do
      post legacy_imports_asana_path, params: { board_id: @board.id, file: fixture_file_upload("moon.jpg", "application/json") }
    end

    asana_import = LegacyImports::AsanaImport.latest_first.first
    assert_redirected_to legacy_imports_asana_import_path(asana_import)
    assert_predicate asana_import.reload, :failed?
    assert_equal "invalid JSON file", asana_import.error_message
  end

  test "show displays import status" do
    perform_enqueued_jobs do
      post legacy_imports_asana_path, params: { board_id: @board.id, file: fixture_file_upload("asana_tasks.json", "application/json") }
    end
    asana_import = LegacyImports::AsanaImport.latest_first.first

    get legacy_imports_asana_import_path(asana_import)

    assert_response :success
    assert_match "Asana Import Status", response.body
    assert_match "Status: Completed", response.body
    assert_match "Issues created", response.body
    assert_match "Review legacy issues", response.body
  end

  test "non admins cannot import" do
    logout_and_sign_in_as :david

    get new_legacy_imports_asana_path

    assert_response :forbidden
  end

  test "support users can open import screen" do
    logout_and_sign_in_as :jz

    get new_legacy_imports_asana_path

    assert_response :success
    assert_match "Import Asana Tasks", response.body
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

    assert_no_difference -> { LegacyImports::AsanaImport.count } do
      post legacy_imports_asana_path, params: { board_id: other_account_board.id, file: fixture_file_upload("asana_tasks.json", "application/json") }
    end

    assert_response :not_found
  end

  test "cannot access another account Asana import" do
    other_account_import = Current.set(account: accounts(:initech), user: users(:mike), identity: users(:mike).identity) do
      LegacyImports::AsanaImport.create!(
        account: accounts(:initech),
        board: boards(:miltons_wish_list),
        creator: users(:mike),
        file: {
          io: StringIO.new(JSON.generate(tasks: [])),
          filename: "asana.json",
          content_type: "application/json"
        }
      )
    end

    get legacy_imports_asana_import_path(other_account_import)

    assert_response :not_found
  end
end
