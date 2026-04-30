class Boards::BugReportsController < ApplicationController
  include BoardScoped

  def new
    @card = @board.cards.build
    @resolution_record = Card::ResolutionRecord.new
  end

  def create
    attributes = bug_report_params
    @card = build_card(attributes)
    @resolution_record = Card::ResolutionRecord.new(attributes.except(:title))

    if @resolution_record.problem_description.blank?
      @resolution_record.errors.add(:problem_description, "can't be blank")
      render :new, status: :unprocessable_entity
      return
    end

    Card.transaction do
      @card.save!
      @card.create_resolution_record!(attributes.except(:title))
    end

    redirect_to @card, notice: "Bug report created"
  end

  private
    def bug_report_params
      params.expect(bug_report: [
        :title,
        :problem_description,
        :reproduction_steps,
        :expected_behavior,
        :actual_behavior,
        :environment_context
      ])
    end

    def build_card(attributes)
      @board.cards.build(
        creator: Current.user,
        status: :published,
        title: attributes[:title].presence || title_from(attributes[:problem_description]),
        description: attributes[:problem_description]
      )
    end

    def title_from(problem_description)
      problem_description.to_s.lines.first.to_s.strip.truncate(80).presence || "Bug report"
    end
end
