module Cards
  class IssueCreator
    REPORT_ATTRIBUTES = %i[
      title
      problem_description
      reproduction_steps
      expected_behavior
      actual_behavior
      environment_context
    ].freeze

    attr_reader :board, :user, :attributes, :card, :resolution_record

    def initialize(board:, user:, attributes:, draft: false)
      @board = board
      @user = user
      @attributes = attributes.to_h.with_indifferent_access.slice(*REPORT_ATTRIBUTES)
      @draft = draft
      @card = build_card
      @resolution_record = Card::ResolutionRecord.new(resolution_attributes)
    end

    def save
      return false unless draft? || valid_report?

      Card.transaction do
        card.save!
        card.create_resolution_record!(resolution_attributes)
        @resolution_record = card.resolution_record
      end

      true
    rescue ActiveRecord::RecordInvalid => error
      merge_record_errors(error.record)
      false
    end

    def creation_notice
      return "Draft issue saved." if draft?

      if resolution_record.gate_one_complete?
        "Issue created and ready for triage."
      else
        "Issue created. Please answer the next reporter question before triage."
      end
    end

    private
      def draft?
        @draft
      end

      def build_card
        board.cards.build(
          creator: user,
          status: draft? ? :drafted : :published,
          title: attributes[:title].presence || title_from(attributes[:problem_description]),
          description: attributes[:problem_description].presence || attributes[:title].to_s
        )
      end

      def resolution_attributes
        attributes.except(:title)
      end

      def valid_report?
        return true unless attributes.values.all? { it.to_s.strip.blank? }

        resolution_record.errors.add(:base, "Add a title or at least one issue detail")
        false
      end

      def title_from(problem_description)
        problem_description.to_s.lines.first.to_s.strip.truncate(80).presence || (draft? ? "Draft issue" : "Issue report")
      end

      def merge_record_errors(record)
        record.errors.full_messages.each { resolution_record.errors.add(:base, it) }
      end
  end
end
