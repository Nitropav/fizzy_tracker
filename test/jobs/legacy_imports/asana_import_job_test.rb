require "test_helper"

class LegacyImports::AsanaImportJobTest < ActiveJob::TestCase
  setup do
    @account = accounts("37s")
    @board = boards(:writebook)
    @creator = users(:kevin)
  end

  test "imports queued Asana tasks" do
    asana_import = build_import(file_fixture("asana_tasks.json").read)

    assert_difference -> { Card.count }, +2 do
      LegacyImports::AsanaImportJob.perform_now(asana_import)
    end

    assert_predicate asana_import.reload, :completed?
    assert_equal 2, asana_import.total_count
    assert_equal 2, asana_import.created_count
    assert_equal 0, asana_import.failed_count
  end

  test "marks invalid JSON as failed" do
    asana_import = build_import("not-json")

    assert_no_difference -> { Card.count } do
      LegacyImports::AsanaImportJob.perform_now(asana_import)
    end

    assert_predicate asana_import.reload, :failed?
    assert_equal "invalid JSON file", asana_import.error_message
  end

  test "continues valid tasks when one task fails" do
    payload = {
      tasks: [
        {
          gid: "partial-1",
          name: "Partial Asana import",
          notes: "Valid imported issue",
          completed: false
        },
        {
          name: "Missing gid"
        }
      ]
    }
    asana_import = build_import(JSON.generate(payload))

    assert_difference -> { Card.count }, +1 do
      LegacyImports::AsanaImportJob.perform_now(asana_import)
    end

    assert_predicate asana_import.reload, :completed_with_errors?
    assert_equal 2, asana_import.total_count
    assert_equal 1, asana_import.created_count
    assert_equal 1, asana_import.failed_count
    assert_includes asana_import.error_message, "task #2"
  end

  private
    def build_import(payload)
      LegacyImports::AsanaImport.new(account: @account, board: @board, creator: @creator).tap do |asana_import|
        asana_import.file.attach(
          io: StringIO.new(payload),
          filename: "asana.json",
          content_type: "application/json"
        )
        asana_import.save!
      end
    end
end
