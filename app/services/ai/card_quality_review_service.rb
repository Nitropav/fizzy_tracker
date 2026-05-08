module Ai
  class CardQualityReviewService
    def initialize(card, user: Current.user, client: Clients::ConfiguredReviewClient.build)
      @card = card
      @user = user
      @client = client
    end

    def review(ai_run: nil)
      run = ai_run || AiRun.create!(
        account: card.account,
        card: card,
        user: user,
        run_type: "card_quality_review",
        input_context: context,
        metadata: metadata
      )

      refresh_queued_run!(run) if ai_run
      run.complete!(output: review_output, metadata: completion_metadata)
      run
    rescue StandardError => error
      run&.fail!(error: error.message, metadata: { "error_class" => error.class.name })
      run
    end

    private
      attr_reader :card, :user, :client

      def context
        @context ||= @ai_run&.input_context.presence || CardContextBuilder.new(card).build
      end

      def refresh_queued_run!(run)
        @ai_run = run
        run.update!(input_context: context, metadata: run.metadata.merge(metadata))
      end

      def review_output
        if client.available?
          client.review_card_quality(context: context)
        else
          deterministic_output
        end
      end

      def deterministic_output
        {
          "status" => ready? ? "ready" : "needs_work",
          "summary" => summary,
          "missing_gate_one_fields" => missing_gate_one_fields,
          "missing_gate_two_fields" => missing_gate_two_fields,
          "warnings" => warnings,
          "suggestions" => suggestions
        }
      end

      def metadata
        {
          "reviewer_type" => client.available? ? "llm" : "deterministic",
          "model" => client.respond_to?(:model) ? client.model : nil
        }.compact
      end

      def completion_metadata
        { "completed_by" => client.available? ? "llm" : "deterministic" }
      end

      def ready?
        missing_gate_one_fields.empty? && missing_gate_two_fields.empty? && warnings.empty?
      end

      def summary
        return "Card is ready to generate or review a training example." if ready?

        "Card needs more structured data before it is a strong training candidate."
      end

      def missing_gate_one_fields
        Array(context.dig("resolution_record", "missing_gate_one_fields"))
      end

      def missing_gate_two_fields
        Array(context.dig("resolution_record", "missing_gate_two_fields"))
      end

      def warnings
        [].tap do |items|
          items << "Structured resolution record is missing." if context["resolution_record"].blank?
          items << "No linked commit or pull request evidence is present." unless code_evidence_present?
        end
      end

      def suggestions
        [].tap do |items|
          items << "Ask the reporter for the missing Gate 1 fields." if missing_gate_one_fields.any?
          items << "Ask the developer to complete the missing Gate 2 fields." if missing_gate_two_fields.any?
          items << "Reference the card in a commit or PR title/body using CT-#{card.number}." unless code_evidence_present?
        end
      end

      def code_evidence_present?
        context.dig("resolution_record", "code_evidence_present") || context["code_links"].any?
      end
  end
end
