module Ai
  class DuplicateIssueSuggestionService
    MAX_CANDIDATES_TO_SCAN = 100
    MAX_RESULTS = 5
    MIN_SCORE = 2
    STOP_WORDS = %w[
      a an and are as at be but by for from has have i in into is it of on or our
      that the this to was we were with you your
    ].freeze

    def initialize(card, user: Current.user)
      @card = card
      @user = user
    end

    def suggest
      AiRun.create!(
        account: card.account,
        card: card,
        user: user,
        run_type: "duplicate_issue_suggestion",
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

      def deterministic_output
        {
          "status" => candidates.any? ? "candidates_found" : "no_candidates",
          "summary" => summary,
          "candidates" => candidates,
          "confidence" => confidence,
          "warnings" => warnings
        }
      end

      def metadata
        {
          "suggestion_type" => "duplicate_issue_suggestion",
          "completed_by" => "deterministic",
          "model" => nil,
          "scan_limit" => MAX_CANDIDATES_TO_SCAN
        }.compact
      end

      def summary
        if candidates.any?
          "Found #{candidates.size} similar #{'issue'.pluralize(candidates.size)} in this account."
        else
          "No strong duplicate candidates found in the latest #{MAX_CANDIDATES_TO_SCAN} account issues."
        end
      end

      def candidates
        @candidates ||= candidate_cards.filter_map do |candidate|
          candidate_record = candidate.resolution_record
          score, reasons = score_candidate(candidate, candidate_record)
          next if score < MIN_SCORE

          {
            "card_id" => candidate.id,
            "number" => candidate.number,
            "title" => candidate.title.to_s,
            "board" => candidate.board.name,
            "closed" => candidate.closed?,
            "workflow_state" => candidate.cactus_workflow_state,
            "score" => score,
            "reasons" => reasons
          }
        end.sort_by { [ -it["score"], it["number"] ] }.first(MAX_RESULTS)
      end

      def candidate_cards
        @candidate_cards ||= card.account.cards.published
          .where.not(id: card.id)
          .includes(:board, :resolution_record, :closure)
          .with_rich_text_description
          .latest
          .limit(MAX_CANDIDATES_TO_SCAN)
          .to_a
      end

      def score_candidate(candidate, candidate_record)
        reasons = []
        score = shared_token_score(candidate, candidate_record)

        if target_record["domain"].present? && target_record["domain"] == candidate_record&.domain
          score += 3
          reasons << "same domain: #{target_record['domain']}"
        end

        if target_record["category"].present? && target_record["category"] == candidate_record&.category
          score += 2
          reasons << "same category: #{target_record['category']}"
        end

        if card.board_id == candidate.board_id
          score += 1
          reasons << "same project"
        end

        [ score, reasons.presence || [ "similar wording" ] ]
      end

      def shared_token_score(candidate, candidate_record)
        shared_tokens = target_tokens & tokens_for(candidate, candidate_record)
        [ shared_tokens.size, 6 ].min
      end

      def target_tokens
        @target_tokens ||= tokens(context_text)
      end

      def target_record
        context.fetch("resolution_record", {}) || {}
      end

      def context_text
        [
          context.dig("card", "title"),
          context.dig("card", "description"),
          target_record["problem_description"],
          target_record["structured_summary"],
          target_record["domain"],
          target_record["category"]
        ].compact_blank.join(" ")
      end

      def tokens_for(candidate, candidate_record)
        tokens([
          candidate.title,
          candidate.description.to_plain_text,
          candidate_record&.problem_description,
          candidate_record&.structured_summary,
          candidate_record&.domain,
          candidate_record&.category
        ].compact_blank.join(" "))
      end

      def tokens(text)
        text.to_s.downcase.scan(/[a-z0-9]+/).reject { STOP_WORDS.include?(it) || it.length < 3 }.uniq
      end

      def confidence
        {
          "duplicate_detection" => candidates.any? ? "medium" : "low"
        }
      end

      def warnings
        [
          "Duplicate suggestions are deterministic similarity matches and must be reviewed by a human."
        ]
      end
  end
end
