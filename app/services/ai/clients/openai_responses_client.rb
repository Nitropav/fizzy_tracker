require "net/http"

module Ai
  module Clients
    class OpenaiResponsesClient
      API_URL = URI("https://api.openai.com/v1/responses")
      DEFAULT_MODEL = "gpt-4.1-mini"

      def initialize(api_key: ENV["OPENAI_API_KEY"], model: ENV.fetch("OPENAI_MODEL", DEFAULT_MODEL))
        @api_key = api_key
        @model = model
      end

      attr_reader :model

      def available?
        api_key.present?
      end

      def review_card_quality(context:)
        raise MissingApiKey, "OPENAI_API_KEY is not configured" unless available?

        response = Net::HTTP.start(API_URL.hostname, API_URL.port, use_ssl: true) do |http|
          http.request(request_for(context))
        end

        raise ApiError, "OpenAI request failed with #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

        parse_output(JSON.parse(response.body))
      end

      MissingApiKey = Class.new(StandardError)
      ApiError = Class.new(StandardError)

      private
        attr_reader :api_key

        def request_for(context)
          Net::HTTP::Post.new(API_URL).tap do |request|
            request["Authorization"] = "Bearer #{api_key}"
            request["Content-Type"] = "application/json"
            request.body = JSON.generate(payload_for(context))
          end
        end

        def payload_for(context)
          {
            model: model,
            instructions: "Review this Fizzy card as a Cactus Bug Tracker training-data candidate. Return only the requested JSON shape. Do not modify the ticket.",
            input: [
              {
                role: "user",
                content: [
                  {
                    type: "input_text",
                    text: JSON.pretty_generate(context)
                  }
                ]
              }
            ],
            text: {
              format: {
                type: "json_schema",
                name: "card_quality_review",
                strict: true,
                schema: response_schema
              }
            }
          }
        end

        def response_schema
          {
            type: "object",
            additionalProperties: false,
            required: %w[ status summary missing_gate_one_fields missing_gate_two_fields warnings suggestions ],
            properties: {
              status: { type: "string", enum: %w[ ready needs_work ] },
              summary: { type: "string" },
              missing_gate_one_fields: { type: "array", items: { type: "string" } },
              missing_gate_two_fields: { type: "array", items: { type: "string" } },
              warnings: { type: "array", items: { type: "string" } },
              suggestions: { type: "array", items: { type: "string" } }
            }
          }
        end

        def parse_output(response_body)
          output_text = response_body.fetch("output").flat_map { |item| Array(item["content"]) }
            .find { |content| content["type"] == "output_text" }
            .fetch("text")

          JSON.parse(output_text)
        rescue KeyError, NoMethodError, JSON::ParserError => error
          raise ApiError, "OpenAI response did not match expected structured output: #{error.message}"
        end
    end
  end
end
