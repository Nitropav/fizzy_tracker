class CardResolutionRecords::IntakeSeeder
  UNTITLED_TITLE = "Untitled"

  def initialize(card)
    @card = card
  end

  def seed!
    record = card.resolution_record || card.build_resolution_record
    record.problem_description = problem_description if record.problem_description.blank? && problem_description.present?

    record.save! if record.new_record? || record.changed?
    record
  end

  private
    attr_reader :card

    def problem_description
      @problem_description ||= [ title_text, description_text ].compact_blank.join("\n\n").presence
    end

    def title_text
      card.title unless card.title.blank? || card.title == UNTITLED_TITLE
    end

    def description_text
      card.description.to_plain_text.strip.presence
    end
end
