require "test_helper"

class LegacyImports::AsanaImportRetriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @board = boards(:writebook)
    @creator = users(:kevin)
  end

  test "failed import can be retried with the same uploaded file" do
    asana_import = create_asana_import(
      status: :failed,
      error_message: "invalid JSON file",
      total_count: 3,
      created_count: 1,
      failed_count: 2,
      completed_at: Time.current
    )

    assert_enqueued_with(job: LegacyImports::AsanaImportJob, args: [ asana_import ]) do
      assert_difference -> { AuditEvent.where(action: "legacy_asana_import.retried").count }, +1 do
        post legacy_imports_asana_import_retry_path(asana_import)
      end
    end

    assert_redirected_to legacy_imports_asana_import_path(asana_import)
    asana_import.reload
    assert_predicate asana_import, :pending?
    assert_nil asana_import.started_at
    assert_nil asana_import.completed_at
    assert_nil asana_import.error_message
    assert_equal 0, asana_import.total_count
    assert_equal 0, asana_import.created_count
    assert_equal 0, asana_import.failed_count
  end

  test "completed import cannot be retried" do
    asana_import = create_asana_import(status: :completed, completed_at: Time.current)

    assert_no_enqueued_jobs do
      post legacy_imports_asana_import_retry_path(asana_import)
    end

    assert_redirected_to legacy_imports_asana_import_path(asana_import)
    assert_predicate asana_import.reload, :completed?
  end

  test "another account import cannot be retried" do
    other_import = Current.set(account: accounts(:initech), user: users(:mike), identity: users(:mike).identity) do
      LegacyImports::AsanaImport.create!(
        account: accounts(:initech),
        board: boards(:miltons_wish_list),
        creator: users(:mike),
        status: :failed,
        error_message: "failed",
        completed_at: Time.current,
        file: {
          io: StringIO.new(JSON.generate(tasks: [])),
          filename: "asana.json",
          content_type: "application/json"
        }
      )
    end

    assert_no_enqueued_jobs do
      post legacy_imports_asana_import_retry_path(other_import)
    end

    assert_response :not_found
  end

  private
    def create_asana_import(attributes = {})
      LegacyImports::AsanaImport.create!(
        {
          account: @board.account,
          board: @board,
          creator: @creator,
          file: {
            io: StringIO.new(JSON.generate(tasks: [])),
            filename: "asana.json",
            content_type: "application/json"
          }
        }.merge(attributes)
      )
    end
end
