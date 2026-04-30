module Ai
  module Clients
    class UnavailableReviewClient
      attr_reader :model

      def initialize
        @model = nil
      end

      def available?
        false
      end

      def review_card_quality(context:)
        raise NotConfigured, "AI review client is not configured"
      end

      NotConfigured = Class.new(StandardError)
    end
  end
end
