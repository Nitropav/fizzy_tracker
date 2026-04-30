require "test_helper"

class Github::TicketReferenceParserTest < ActiveSupport::TestCase
  test "extracts unique card numbers from CT references" do
    parser = Github::TicketReferenceParser.new("Fix CT-123 and ct-456", "Refs CT-123")

    assert_equal [ 123, 456 ], parser.card_numbers
  end

  test "ignores text without card references" do
    assert_empty Github::TicketReferenceParser.new("No ticket here").card_numbers
  end
end
