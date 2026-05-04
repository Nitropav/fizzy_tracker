module Ai
  class IssueStructuringService
    def initialize(card, user: Current.user)
      @card = card
      @user = user
    end

    def suggest
      AiRun.create!(
        account: card.account,
        card: card,
        user: user,
        run_type: "issue_structuring",
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

      def deterministic_output
        {
          "status" => "suggested",
          "summary" => "Generated deterministic Gate 1 and classification suggestions from the issue title, description, tags, and project context.",
          "suggested_fields" => suggested_fields,
          "confidence" => confidence,
          "warnings" => warnings
        }
      end

      def metadata
        {
          "suggestion_type" => "issue_structuring",
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
          "priority" => priority,
          "category" => category,
          "domain" => domain,
          "severity" => severity
        }.compact_blank
      end

      def problem_description
        first_present(record_context["problem_description"], description, title)
      end

      def reproduction_steps
        record_context["reproduction_steps"].presence ||
          "Open the affected ES Windows workflow and follow the reporter's path until the issue appears."
      end

      def expected_behavior
        record_context["expected_behavior"].presence ||
          "The affected workflow should complete without the reported incorrect behavior."
      end

      def actual_behavior
        record_context["actual_behavior"].presence || first_present(description, title)
      end

      def environment_context
        first_present(
          record_context["environment_context"],
          [ account_name, project_name, column_name ].compact_blank.join(" / "),
          "ES Windows"
        )
      end

      def structured_summary
        first_present(record_context["structured_summary"], title, problem_description)
      end

      def priority
        first_present(record_context["priority"], inferred_priority)
      end

      def category
        first_present(record_context["category"], inferred_category)
      end

      def domain
        first_present(record_context["domain"], inferred_domain, "other")
      end

      def severity
        first_present(record_context["severity"], inferred_severity)
      end

      def confidence
        {
          "gate_one" => description.present? ? "medium" : "low",
          "classification" => (tag_titles.any? || matched_domain.present?) ? "medium" : "low"
        }
      end

      def warnings
        [].tap do |items|
          items << "Issue description is empty; suggestions are mostly based on the title." if description.blank?
          items << "Suggested reproduction, expected, and actual fields are generic placeholders and should be reviewed by a human." if missing_gate_one_fields.any?
        end
      end

      def missing_gate_one_fields
        Array(record_context["missing_gate_one_fields"])
      end

      def title
        context.dig("card", "title").to_s.presence
      end

      def description
        context.dig("card", "description").to_s.presence
      end

      def account_name
        context.dig("account", "name")
      end

      def project_name
        context.dig("board", "name")
      end

      def column_name
        context.dig("column", "name")
      end

      def tag_titles
        Array(context["tags"]).filter_map { it["title"] if it.respond_to?(:[]) }
      end

      def inferred_priority
        text = searchable_text

        return "urgent" if text.match?(/blocked|cannot order|production down|urgent/i)
        return "high" if text.match?(/wrong price|pricing|customer cannot|can't|cannot|error|fails/i)

        "normal"
      end

      def inferred_category
        text = searchable_text

        return "feature request" if text.match?(/feature|request|enhancement|would like/i)
        return "question" if text.match?(/\?|how do i|how to|question/i)
        return "configuration error" if text.match?(/config|configuration|setting|setup/i)
        return "bug" if text.present?

        nil
      end

      def inferred_domain
        matched_domain || tag_titles.first
      end

      def matched_domain
        text = searchable_text

        Card::ResolutionRecord::DOMAINS.find do |domain|
          normalized = domain.tr("/", " ")
          text.match?(/\b#{Regexp.escape(normalized)}\b/i) || text.match?(/\b#{Regexp.escape(domain)}\b/i)
        end
      end

      def inferred_severity
        text = searchable_text

        return "blocks ordering" if text.match?(/cannot order|can't order|blocks ordering|order blocked/i)
        return "blocks workflow" if text.match?(/blocked|cannot continue|can't continue/i)
        return "cosmetic" if text.match?(/alignment|typo|color|cosmetic/i)
        return "degrades experience" if text.present?

        "needs investigation"
      end

      def searchable_text
        [ title, description, project_name, column_name, *tag_titles ].compact_blank.join(" ")
      end

      def first_present(*values)
        values.find(&:present?)
      end
  end
end
