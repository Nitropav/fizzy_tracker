module TrainingExamples
  class JsonlExporter
    SYSTEM_PROMPT = "<eswindows> You are an expert operator helping diagnose and resolve ES Windows production issues.".freeze

    def initialize(training_examples)
      @training_examples = training_examples
    end

    def to_jsonl
      training_examples.map { |training_example| JSON.generate(payload_for(training_example)) }.join("\n").then do |jsonl|
        jsonl.present? ? "#{jsonl}\n" : ""
      end
    end

    private
      attr_reader :training_examples

      def payload_for(training_example)
        {
          messages: [
            { role: "system", content: SYSTEM_PROMPT },
            { role: "user", content: user_content(training_example) },
            { role: "assistant", content: assistant_content(training_example) }
          ],
          metadata: metadata_for(training_example)
        }
      end

      def user_content(training_example)
        [
          "Problem summary:",
          training_example.problem_summary.presence || "N/A",
          "",
          "Structured context:",
          JSON.pretty_generate(training_example.input_context.fetch("resolution_record", {}))
        ].join("\n")
      end

      def assistant_content(training_example)
        [
          "Root cause:",
          training_example.root_cause.presence || "N/A",
          "",
          "Resolution:",
          training_example.resolution_summary.presence || "N/A",
          "",
          "Verification:",
          training_example.verification_steps.presence || "N/A"
        ].join("\n")
      end

      def metadata_for(training_example)
        training_example.metadata.merge(
          "training_example_id" => training_example.id,
          "status" => training_example.status,
          "reviewed_by_id" => training_example.reviewed_by_id,
          "reviewed_at" => training_example.reviewed_at&.iso8601,
          "exported_at" => Time.current.iso8601
        )
      end
  end
end
