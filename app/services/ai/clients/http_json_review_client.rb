require "net/http"

module Ai
  module Clients
    class HttpJsonReviewClient
      DEFAULT_TIMEOUT = 30

      def initialize(
        endpoint: ENV["AI_REVIEW_ENDPOINT"],
        api_key: ENV["AI_REVIEW_API_KEY"],
        model: ENV["AI_REVIEW_MODEL"],
        timeout: ENV.fetch("AI_REVIEW_TIMEOUT", DEFAULT_TIMEOUT).to_i
      )
        @endpoint = endpoint
        @api_key = api_key
        @model = model
        @timeout = timeout
      end

      attr_reader :model

      def available?
        endpoint.present?
      end

      def review_card_quality(context:)
        raise MissingEndpoint, "AI_REVIEW_ENDPOINT is not configured" unless available?

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", read_timeout: timeout, open_timeout: timeout) do |http|
          http.request(request_for(context))
        end

        raise ApiError, "AI review request failed with #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

        normalize_response(JSON.parse(response.body))
      end

      MissingEndpoint = Class.new(StandardError)
      ApiError = Class.new(StandardError)

      private
        attr_reader :endpoint, :api_key, :timeout

        def uri
          @uri ||= URI(endpoint)
        end

        def request_for(context)
          Net::HTTP::Post.new(uri).tap do |request|
            request["Content-Type"] = "application/json"
            request["Authorization"] = "Bearer #{api_key}" if api_key.present?
            request.body = JSON.generate(payload_for(context))
          end
        end

        def payload_for(context)
          {
            task: "card_quality_review",
            model: model,
            schema_version: 1,
            context: context
          }.compact
        end

        def normalize_response(response_body)
          output = response_body["output"] || response_body
          required_keys.each_with_object({}) do |key, normalized|
            normalized[key] = output.fetch(key)
          end
        rescue KeyError => error
          raise ApiError, "AI review response is missing required key: #{error.key}"
        end

        def required_keys
          %w[ status summary missing_gate_one_fields missing_gate_two_fields warnings suggestions ]
        end
    end
  end
end
