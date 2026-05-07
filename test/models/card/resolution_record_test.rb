require "test_helper"

class Card::ResolutionRecordTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @card = cards(:logo)
  end

  test "defaults account from card" do
    record = @card.create_resolution_record!

    assert_equal @card.account, record.account
  end

  test "tracks missing gate one fields" do
    record = @card.create_resolution_record!(
      problem_description: "Card image is too small",
      expected_behavior: "Logo should be readable"
    )

    assert_not record.gate_one_complete?
    assert_equal %i[ reproduction_steps actual_behavior environment_context ], record.missing_gate_one_fields
    assert record.gate_one_status_incomplete?
  end

  test "marks gate one complete when required reporter fields are present" do
    record = @card.create_resolution_record!(gate_one_attrs)

    assert record.gate_one_complete?
    assert record.gate_one_status_complete?
  end

  test "marks gate two complete when required developer fields are present" do
    record = @card.create_resolution_record!(gate_two_attrs)

    assert record.gate_two_complete?
    assert record.gate_two_status_complete?
  end

  test "normalizes blank array values" do
    record = @card.create_resolution_record!(
      suggested_primitives: [ "pricing", "", nil ],
      linked_commit_shas: [ "abc123", "" ],
      linked_pr_urls: [ nil, "https://github.com/example/repo/pull/1" ]
    )

    assert_equal [ "pricing" ], record.suggested_primitives
    assert_equal [ "abc123" ], record.linked_commit_shas
    assert_equal [ "https://github.com/example/repo/pull/1" ], record.linked_pr_urls
    assert record.code_evidence_present?
  end

  test "classification options preserve existing custom values" do
    assert_includes Card::ResolutionRecord.category_options, "bug"
    assert_includes Card::ResolutionRecord.domain_options, "assembly config"
    assert_includes Card::ResolutionRecord.severity_options, "blocks ordering"
    assert_includes Card::ResolutionRecord.priority_options, "urgent"

    assert_includes Card::ResolutionRecord.category_options("custom category"), "custom category"
    assert_includes Card::ResolutionRecord.domain_options("custom domain"), "custom domain"
    assert_includes Card::ResolutionRecord.severity_options("custom severity"), "custom severity"
    assert_includes Card::ResolutionRecord.priority_options("custom priority"), "custom priority"
  end

  test "requires one resolution record per card" do
    @card.create_resolution_record!
    duplicate = Card::ResolutionRecord.new(card: @card)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:card_id], "has already been taken"
  end

  test "requires account to match card account" do
    record = Card::ResolutionRecord.new(card: @card, account: accounts(:initech))

    assert_not record.valid?
    assert_includes record.errors[:account], "must match the card account"
  end

  test "legacy unresolved records stop needing structuring when gate one is complete" do
    record = @card.create_resolution_record!(
      legacy_import: true,
      legacy_source: "asana",
      legacy_external_id: "unresolved-1",
      legacy_imported_at: Time.current,
      legacy_metadata: { "completed" => false },
      needs_structuring: true
    )

    record.update!(gate_one_attrs)

    assert_not record.needs_structuring?
    assert record.legacy_structuring_complete?
    assert_empty record.legacy_structuring_blockers
  end

  test "legacy resolved records need gate two before structuring is complete" do
    record = @card.create_resolution_record!(
      legacy_import: true,
      legacy_source: "asana",
      legacy_external_id: "resolved-1",
      legacy_imported_at: Time.current,
      legacy_metadata: { "completed" => true },
      needs_structuring: true
    )

    record.update!(gate_one_attrs)

    assert record.needs_structuring?
    assert_not record.legacy_structuring_complete?
    assert_includes record.legacy_structuring_blockers, "Gate 2 root cause"

    record.update!(gate_two_attrs)

    assert_not record.needs_structuring?
    assert record.legacy_structuring_complete?
    assert_empty record.legacy_structuring_blockers
  end

  test "legacy training candidate requires both gates" do
    record = @card.create_resolution_record!(
      legacy_import: true,
      legacy_source: "asana",
      legacy_external_id: "candidate-1",
      legacy_imported_at: Time.current,
      legacy_metadata: { "completed" => true },
      needs_structuring: true
    )

    assert_not record.legacy_training_candidate_ready?
    assert_includes record.legacy_training_candidate_blockers, "Gate 1 problem description"
    assert_includes record.legacy_training_candidate_blockers, "Gate 2 root cause"

    record.update!(gate_one_attrs)

    assert_not record.legacy_training_candidate_ready?
    assert_not_includes record.legacy_training_candidate_blockers, "Gate 1 problem description"
    assert_includes record.legacy_training_candidate_blockers, "Gate 2 root cause"

    record.update!(gate_two_attrs)

    assert record.legacy_training_candidate_ready?
    assert_empty record.legacy_training_candidate_blockers
  end

  private
    def gate_one_attrs
      {
        problem_description: "Card image is too small",
        reproduction_steps: "Open the board and inspect the logo card",
        expected_behavior: "Logo should be readable",
        actual_behavior: "Logo is too small",
        environment_context: "Fizzy card detail page"
      }
    end

    def gate_two_attrs
      {
        root_cause: "Image sizing used the wrong max width",
        fix_summary: "Adjusted the card image layout",
        verification_steps: "Opened the card and confirmed the logo is readable"
      }
    end
end
