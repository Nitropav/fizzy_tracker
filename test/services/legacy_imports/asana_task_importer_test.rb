require "test_helper"

class LegacyImports::AsanaTaskImporterTest < ActiveSupport::TestCase
  test "maps an Asana task into a legacy card import" do
    result = LegacyImports::AsanaTaskImporter.new(
      account: accounts("37s"),
      board: boards(:writebook),
      creator: users(:david)
    ).import(asana_task)

    assert result.created
    assert_equal "asana", result.resolution_record.legacy_source
    assert_equal "120123", result.resolution_record.legacy_external_id
    assert_equal "Legacy glass issue", result.card.title
    assert_equal "Customer says glass is invisible", result.resolution_record.problem_description
    assert_equal "ES Windows / Glass", result.resolution_record.environment_context
    assert_equal "glass_visibility", result.resolution_record.domain
    assert_predicate result.resolution_record, :needs_structuring?
  end

  private
    def asana_task
      {
        gid: "120123",
        name: "Legacy glass issue",
        notes: "Customer says glass is invisible",
        completed: true,
        created_at: "2025-01-01T10:00:00Z",
        modified_at: "2025-01-02T10:00:00Z",
        permalink_url: "https://app.asana.com/0/1/120123",
        workspace: { name: "ES Windows" },
        projects: [ { name: "Glass" } ],
        tags: [ { name: "glass_visibility" } ],
        assignee: { name: "Developer" }
      }
    end
end
