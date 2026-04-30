module Ai
  module Clients
    class ConfiguredReviewClient
      def self.build
        if ENV["AI_REVIEW_ENDPOINT"].present?
          HttpJsonReviewClient.new
        elsif ENV["OPENAI_API_KEY"].present?
          OpenaiResponsesClient.new
        else
          UnavailableReviewClient.new
        end
      end
    end
  end
end
