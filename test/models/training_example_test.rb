require "test_helper"

class TrainingExampleTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @card = cards(:logo)
  end

  test "defaults account from card" do
    training_example = @card.training_examples.create!(
      input_context: { "card" => { "id" => @card.id } },
      metadata: { "card_id" => @card.id }
    )

    assert_equal @card.account, training_example.account
    assert training_example.draft?
  end

  test "review lifecycle" do
    training_example = @card.training_examples.create!(
      input_context: { "card" => { "id" => @card.id } },
      metadata: { "card_id" => @card.id }
    )

    training_example.submit_for_review!
    assert training_example.pending_review?

    training_example.approve!(reviewer: users(:david), notes: "Looks good")
    assert training_example.approved?
    assert_equal users(:david), training_example.reviewed_by
    assert_equal "Looks good", training_example.review_notes
    assert training_example.reviewed_at.present?

    training_example.mark_exported!
    assert training_example.exported?
    assert training_example.exported_at.present?
  end

  test "reject lifecycle" do
    training_example = @card.training_examples.create!(
      input_context: { "card" => { "id" => @card.id } },
      metadata: { "card_id" => @card.id }
    )

    training_example.reject!(reviewer: users(:david), notes: "Needs more detail")

    assert training_example.rejected?
    assert_equal "Needs more detail", training_example.review_notes
  end

  test "requires account to match card account" do
    training_example = TrainingExample.new(
      card: @card,
      account: accounts(:initech),
      input_context: { "card" => { "id" => @card.id } },
      metadata: { "card_id" => @card.id }
    )

    assert_not training_example.valid?
    assert_includes training_example.errors[:account], "must match the card account"
  end

  test "requires reviewer to belong to account" do
    training_example = @card.training_examples.build(
      input_context: { "card" => { "id" => @card.id } },
      metadata: { "card_id" => @card.id },
      reviewed_by: users(:mike)
    )

    assert_not training_example.valid?
    assert_includes training_example.errors[:reviewed_by], "must belong to the training example account"
  end
end
