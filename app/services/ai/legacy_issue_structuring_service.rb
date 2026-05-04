module Ai
  class LegacyIssueStructuringService
    def initialize(card, user: Current.user)
      @card = card
      @user = user
    end

    def suggest
      AiRun.create!(
        account: card.account,
        card: card,
        user: user,
        run_type: "legacy_issue_structuring",
        input_context: context,
        metadata: metadata
      ).tap do |run|
        run.complete!(output: deterministic_output, metadata: { "completed_by" => "deterministic" })
      rescue StandardError => error
        run.fail!(error: error.message, metadata: { "error_class" => error.class.name })
      end
    end

    private
      attr_reader :card, :user

      def context
        @context ||= CardContextBuilder.new(card).build
      end

      def record_context
        context.fetch("resolution_record", {}) || {}
      end

      def legacy_metadata
        record_context.fetch("legacy_metadata", {}) || {}
      end

      def deterministic_output
        {
          "status" => "suggested",
          "summary" => "Generated deterministic structuring suggestions from imported Asana title, notes, and metadata.",
          "suggested_fields" => suggested_fields,
          "confidence" => confidence,
          "warnings" => warnings
        }
      end

      def metadata
        {
          "suggestion_type" => "legacy_issue_structuring",
          "completed_by" => "deterministic",
          "model" => nil
        }.compact
      end

      def suggested_fields
        {
          "problem_description" => problem_description,
          "reproduction_steps" => reproduction_steps,
          "expected_behavior" => expected_behavior,
          "actual_behavior" => actual_behavior,
          "environment_context" => environment_context,
          "structured_summary" => structured_summary,
          "category" => category,
          "domain" => domain,
          "severity" => severity,
          "root_cause" => root_cause,
          "fix_summary" => fix_summary,
          "verification_steps" => verification_steps
        }.compact_blank
      end

      def problem_description
        first_present(
          record_context["problem_description"],
          card_description,
          title
        )
      end

      def reproduction_steps
        record_context["reproduction_steps"].presence ||
          "Review the imported Asana task and reproduce the reported behavior in the referenced ES Windows workflow."
      end

      def expected_behavior
        record_context["expected_behavior"].presence ||
          "The affected workflow should behave according to the product expectation described in the imported task."
      end

      def actual_behavior
        record_context["actual_behavior"].presence ||
          first_present(card_description, title)
      end

      def environment_context
        first_present(
          record_context["environment_context"],
          imported_environment_context,
          "Legacy Asana import"
        )
      end

      def structured_summary
        first_present(record_context["structured_summary"], title, problem_description)
      end

      def category
        first_present(record_context["category"], inferred_category)
      end

      def domain
        first_present(record_context["domain"], imported_tags.first, "other")
      end

      def severity
        first_present(record_context["severity"], "needs investigation")
      end

      def root_cause
        return record_context["root_cause"] if record_context["root_cause"].present?
        return unless legacy_completed?

        "Legacy task was marked complete in Asana. Confirm the historical root cause from linked implementation notes or commits before approval."
      end

      def fix_summary
        return record_context["fix_summary"] if record_context["fix_summary"].present?
        return unless legacy_completed?

        "Legacy task was marked complete in Asana. Summarize the actual fix from the historical implementation before approval."
      end

      def verification_steps
        return record_context["verification_steps"] if record_context["verification_steps"].present?
        return unless legacy_completed?

        "Verify the resolved behavior in the relevant ES Windows workflow and record the exact checks before approving training data."
      end

      def confidence
        {
          "gate_one" => card_description.present? ? "medium" : "low",
          "gate_two" => legacy_completed? ? "low" : "not_applicable"
        }
      end

      def warnings
        [].tap do |items|
          items << "Gate 2 suggestions are placeholders because the imported Asana task has no linked code evidence." if legacy_completed?
          items << "Imported task notes are empty; suggestions are based mostly on title and metadata." if card_description.blank?
        end
      end

      def title
        context.dig("card", "title").to_s.presence
      end

      def card_description
        context.dig("card", "description").to_s.presence
      end

      def imported_environment_context
        workspace = legacy_metadata.dig("workspace", "name")
        projects = Array(legacy_metadata["projects"]).filter_map { it["name"] if it.respond_to?(:[]) }

        [ workspace, *projects ].compact_blank.join(" / ").presence
      end

      def imported_tags
        Array(legacy_metadata["tags"]).filter_map { it["name"] if it.respond_to?(:[]) }
      end

      def inferred_category
        return "bug" if title.to_s.match?(/bug|error|broken|issue|cannot|wrong/i) || card_description.to_s.match?(/bug|error|broken|cannot|wrong/i)
        return "task" if title.present?

        nil
      end

      def legacy_completed?
        legacy_metadata["completed"] == true || legacy_metadata["completed_at"].present?
      end

      def first_present(*values)
        values.find(&:present?)
      end
  end
end
