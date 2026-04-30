module Github
  class TicketReferenceParser
    CARD_REFERENCE_PATTERN = /\bCT-(\d+)\b/i

    def initialize(*texts)
      @texts = texts
    end

    def card_numbers
      texts.flat_map { |text| text.to_s.scan(CARD_REFERENCE_PATTERN).flatten }
        .map(&:to_i)
        .uniq
    end

    private
      attr_reader :texts
  end
end
