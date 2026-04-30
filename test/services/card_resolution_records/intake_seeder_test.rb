require "test_helper"

class CardResolutionRecords::IntakeSeederTest < ActiveSupport::TestCase
  setup do
    Current.session = sessions(:david)
    @card = cards(:logo)
  end

  test "creates resolution record from card title and description" do
    @card.update!(title: "Checkout price is wrong", description: "Total changes after refresh.")

    assert_difference -> { Card::ResolutionRecord.count }, +1 do
      @record = CardResolutionRecords::IntakeSeeder.new(@card).seed!
    end

    assert_includes @record.problem_description, "Checkout price is wrong"
    assert_includes @record.problem_description, "Total changes after refresh."
    assert_not @record.gate_one_complete?
  end

  test "does not overwrite existing reporter description" do
    record = @card.create_resolution_record!(problem_description: "Existing reporter text")
    @card.update!(title: "New title")

    CardResolutionRecords::IntakeSeeder.new(@card).seed!

    assert_equal "Existing reporter text", record.reload.problem_description
  end

  test "creates blank record when no useful title or description is present" do
    @card.update!(title: "Untitled", description: "")

    record = CardResolutionRecords::IntakeSeeder.new(@card).seed!

    assert record.persisted?
    assert_nil record.problem_description
    assert_equal Card::ResolutionRecord::GATE_ONE_REQUIRED_FIELDS, record.missing_gate_one_fields
  end
end
