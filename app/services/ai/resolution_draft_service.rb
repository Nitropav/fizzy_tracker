module Ai
  class ResolutionDraftService
    def initialize(card, user: Current.user)
      @card = card
      @user = user
    end

    def suggest
      AiRun.create!(
        account: card.account,
        card: card,
        user: user,
        run_type: "resolution_draft",
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
          "summary" => "Generated deterministic Gate 2 draft from linked code evidence and structured issue context.",
          "suggested_fields" => suggested_fields,
          "evidence" => evidence_payload,
          "confidence" => confidence,
          "warnings" => warnings
        }
      end

      def metadata
        {
          "suggestion_type" => "resolution_draft",
          "completed_by" => "deterministic",
          "model" => nil
        }.compact
      end

      def suggested_fields
        {
          "root_cause" => root_cause,
          "fix_summary" => fix_summary,
          "verification_steps" => verification_steps
        }.compact_blank
      end

      def root_cause
        first_present(
          record_context["root_cause"],
          "The issue appears related to #{issue_area}. Confirm the exact technical cause by reviewing the linked code evidence: #{evidence_sentence}."
        )
      end

      def fix_summary
        first_present(
          record_context["fix_summary"],
          "Applied the changes referenced by #{evidence_sentence} to address #{issue_summary.downcase}."
        )
      end

      def verification_steps
        first_present(
          record_context["verification_steps"],
          "Reproduce the original issue, verify the expected behavior now holds, and run focused checks around #{issue_area}."
        )
      end

      def issue_area
        first_present(record_context["domain"], context.dig("board", "name"), "the affected workflow")
      end

      def issue_summary
        first_present(record_context["structured_summary"], record_context["problem_description"], context.dig("card", "title"), "the reported issue")
      end

      def evidence_payload
        {
          "code_links" => code_links,
          "manual_commit_shas" => manual_commit_shas,
          "manual_pr_urls" => manual_pr_urls
        }
      end

      def evidence_sentence
        evidence_labels.presence&.to_sentence || "the available developer evidence"
      end

      def evidence_labels
        [
          *code_links.map { code_link_label(it) },
          *manual_commit_shas.map { "commit #{it}" },
          *manual_pr_urls.map { "PR #{it}" }
        ].uniq
      end

      def code_link_label(code_link)
        title = code_link["title"].presence
        external_type = code_link["external_type"].to_s.tr("_", " ")
        external_id = code_link["sha"].presence || code_link["external_id"].presence || code_link["url"].presence

        [ title, [ external_type, external_id ].compact_blank.join(" ") ].compact_blank.join(" - ")
      end

      def code_links
        Array(context["code_links"])
      end

      def manual_commit_shas
        Array(record_context["linked_commit_shas"]).compact_blank
      end

      def manual_pr_urls
        Array(record_context["linked_pr_urls"]).compact_blank
      end

      def code_evidence_present?
        code_links.any? || manual_commit_shas.any? || manual_pr_urls.any?
      end

      def confidence
        {
          "resolution" => code_evidence_present? ? "medium" : "low",
          "evidence" => code_links.any? ? "medium" : (code_evidence_present? ? "low" : "none")
        }
      end

      def warnings
        [].tap do |items|
          items << "No linked commit or PR evidence is present; the draft is generic and should not be accepted as-is." unless code_evidence_present?
          items << "Generated Gate 2 fields are deterministic drafts and require developer review before resolving the issue."
        end
      end

      def first_present(*values)
        values.find(&:present?)
      end
  end
end
