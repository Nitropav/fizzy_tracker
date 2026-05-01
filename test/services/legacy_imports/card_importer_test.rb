require "test_helper"

class LegacyImports::CardImporterTest < ActiveSupport::TestCase
  setup do
    @account = accounts("37s")
    @board = boards(:writebook)
    @creator = users(:david)
    @importer = LegacyImports::CardImporter.new(account: @account, board: @board, creator: @creator)
  end

  test "creates a published legacy card with structured import metadata" do
    result = nil

    assert_difference -> { Card.count }, 1 do
      assert_difference -> { Card::ResolutionRecord.count }, 1 do
        result = @importer.import(
          source: "asana",
          external_id: "1200",
          title: "Imported task",
          description: "Customer reported imported issue",
          fields: {
            problem_description: "Customer reported imported issue",
            environment_context: "Asana project"
          },
          metadata: { gid: "1200", permalink_url: "https://app.asana.com/0/1/1200" }
        )
      end
    end

    assert result.created
    assert_predicate result.card, :published?
    assert_equal @account, result.card.account
    assert_equal @board, result.card.board
    assert_equal @creator, result.card.creator
    assert_equal "Imported task", result.card.title

    record = result.resolution_record
    assert_predicate record, :legacy_import?
    assert_predicate record, :gate_one_legacy?
    assert_predicate record, :needs_structuring?
    assert_equal "asana", record.legacy_source
    assert_equal "1200", record.legacy_external_id
    assert_equal "https://app.asana.com/0/1/1200", record.legacy_metadata["permalink_url"]
    assert_equal false, record.legacy_metadata["completed"]
    assert_equal "incomplete", record.gate_one_status
  end

  test "is idempotent by account source and external id" do
    first = @importer.import(source: "asana", external_id: "1200", title: "Imported task")

    assert_no_difference -> { Card.count } do
      assert_no_difference -> { Card::ResolutionRecord.count } do
        second = @importer.import(source: "asana", external_id: "1200", title: "Imported task duplicate")

        assert_not second.created
        assert_equal first.card, second.card
        assert_equal first.resolution_record, second.resolution_record
      end
    end
  end

  test "marks fully structured resolved imports as not needing structuring" do
    result = @importer.import(
      source: "asana",
      external_id: "1201",
      title: "Complete task",
      resolved: true,
      fields: gate_one_attrs.merge(gate_two_attrs)
    )

    assert_not result.resolution_record.needs_structuring?
    assert_equal "complete", result.resolution_record.gate_one_status
    assert_equal "complete", result.resolution_record.gate_two_status
  end

  test "keeps resolved imports needing structuring when gate two is missing" do
    result = @importer.import(
      source: "asana",
      external_id: "1203",
      title: "Resolved task missing developer data",
      resolved: true,
      fields: gate_one_attrs
    )

    assert result.resolution_record.needs_structuring?
    assert result.resolution_record.legacy_resolved?
    assert_equal true, result.resolution_record.legacy_metadata["completed"]
    assert_equal "complete", result.resolution_record.gate_one_status
    assert_equal "incomplete", result.resolution_record.gate_two_status
  end

  test "rejects cross-account board and creator mismatches" do
    importer = LegacyImports::CardImporter.new(
      account: @account,
      board: boards(:miltons_wish_list),
      creator: @creator
    )

    assert_raises(ArgumentError) do
      importer.import(source: "asana", external_id: "1202", title: "Wrong account")
    end
  end

  private
    def gate_one_attrs
      {
        problem_description: "Imported problem",
        reproduction_steps: "Open the imported task",
        expected_behavior: "Expected text",
        actual_behavior: "Actual text",
        environment_context: "Legacy Asana"
      }
    end

    def gate_two_attrs
      {
        root_cause: "Legacy root cause",
        fix_summary: "Legacy fix",
        verification_steps: "Legacy verification"
      }
    end
end
