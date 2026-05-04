require "test_helper"

class Card::CloseableTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
  end

  test "closed scope" do
    assert_equal [ cards(:shipping) ], Card.closed
    assert_not_includes Card.open, cards(:shipping)
  end

  test "close cards" do
    assert_not cards(:logo).closed?

    assert_difference -> { cards(:logo).events.count }, +1 do
      cards(:logo).close(user: users(:kevin))
    end

    assert cards(:logo).closed?
    assert cards(:logo).events.last.action.card_closed?
    assert_equal users(:kevin), cards(:logo).closed_by
  end

  test "close cards without a resolution record remains allowed" do
    card = cards(:logo)
    assert_nil card.resolution_record

    card.close

    assert card.closed?
  end

  test "close is blocked when resolution record has incomplete gate two" do
    card = cards(:logo)
    card.create_resolution_record!(root_cause: "Known cause")

    error = assert_raises Card::Closeable::GateTwoIncomplete do
      card.close
    end

    assert_match "Complete Gate 2", error.message
    assert_not card.closed?
  end

  test "close is blocked when resolution record is not review-ready" do
    card = cards(:logo)
    card.create_resolution_record!(
      root_cause: "Image sizing used the wrong max width",
      fix_summary: "Adjusted the card image layout",
      verification_steps: "Opened the card and confirmed the logo is readable",
      linked_commit_shas: [ "abc123" ]
    )

    error = assert_raises Card::Closeable::ResolutionNotReady do
      card.close
    end

    assert_match "Move this issue into active work", error.message
    assert_not card.closed?
  end

  test "close generates training example when both gates are complete" do
    card = cards(:logo)
    card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small",
      environment_context: "Fizzy card page",
      root_cause: "Image sizing used the wrong max width",
      fix_summary: "Adjusted the card image layout",
      verification_steps: "Opened the card and confirmed the logo is readable",
      linked_commit_shas: [ "abc123" ]
    )

    assert_difference -> { card.training_examples.count }, +1 do
      card.close
    end

    assert card.training_examples.last.pending_review?
  end

  test "resolve closes card and generates training example when both gates are complete" do
    card = cards(:logo)
    card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small",
      environment_context: "Fizzy card page",
      root_cause: "Image sizing used the wrong max width",
      fix_summary: "Adjusted the card image layout",
      verification_steps: "Opened the card and confirmed the logo is readable",
      linked_commit_shas: [ "abc123" ]
    )

    training_example = nil
    assert_difference -> { card.training_examples.count }, +1 do
      training_example = card.resolve
    end

    assert card.closed?
    assert training_example.pending_review?
  end

  test "close is blocked when gate one is incomplete" do
    card = cards(:logo)
    card.create_resolution_record!(
      root_cause: "Image sizing used the wrong max width",
      fix_summary: "Adjusted the card image layout",
      verification_steps: "Opened the card and confirmed the logo is readable",
      linked_commit_shas: [ "abc123" ]
    )

    assert_no_difference -> { card.training_examples.count } do
      assert_raises Card::Closeable::ResolutionNotReady do
        card.close
      end
    end

    assert_not card.closed?
  end

  test "close is blocked when code evidence is missing" do
    card = cards(:logo)
    card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small",
      environment_context: "Fizzy card page",
      root_cause: "Image sizing used the wrong max width",
      fix_summary: "Adjusted the card image layout",
      verification_steps: "Opened the card and confirmed the logo is readable"
    )

    error = assert_raises Card::Closeable::CodeEvidenceMissing do
      card.close
    end

    assert_match "Add code evidence", error.message
    assert_not card.closed?
  end

  test "close accepts linked github code evidence" do
    card = cards(:logo)
    card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small",
      environment_context: "Fizzy card page",
      root_cause: "Image sizing used the wrong max width",
      fix_summary: "Adjusted the card image layout",
      verification_steps: "Opened the card and confirmed the logo is readable"
    )
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

    card.close

    assert card.closed?
  end

  test "reopen cards" do
    assert cards(:shipping).closed?

    assert_difference -> { cards(:shipping).events.count }, +1 do
      cards(:shipping).reopen
    end
    assert cards(:shipping).reload.open?
    assert cards(:shipping).events.last.action.card_reopened?
  end

  test "close card from triage column" do
    card = cards(:logo)
    assert_equal columns(:writebook_triage), card.column

    card.close
    assert card.closed?
  end

  test "close card from active column" do
    card = cards(:text)
    assert_equal columns(:writebook_in_progress), card.column

    card.close
    assert card.closed?
  end

  test "close card from NOT NOW" do
    card = cards(:logo)

    card.postpone
    assert card.postponed?
    assert card.not_now.present?

    card.close
    assert card.closed?
    assert_nil card.reload.not_now
  end
end
