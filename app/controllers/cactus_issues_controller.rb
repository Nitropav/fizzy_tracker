class CactusIssuesController < ApplicationController
  before_action :ensure_can_create_cactus_issue

  def new
    load_projects
    @board = @boards.first
    @card = @board&.cards&.build || Card.new
    @resolution_record = Card::ResolutionRecord.new
  end

  def create
    load_projects
    attributes = cactus_issue_params
    draft = ActiveModel::Type::Boolean.new.cast(attributes.delete(:draft))
    @board = @boards.find { it.id == attributes[:board_id] }

    unless @board
      @card = Card.new(title: attributes[:title], description: attributes[:description])
      @resolution_record = Card::ResolutionRecord.new(attributes.except(:board_id, :title, :description))
      @resolution_record.errors.add(:base, "Select a project")
      render :new, status: :unprocessable_entity
      return
    end

    issue_creator = Cards::IssueCreator.new(
      board: @board,
      user: Current.user,
      attributes: attributes.except(:board_id),
      draft: draft
    )

    @card = issue_creator.card
    @resolution_record = issue_creator.resolution_record

    unless issue_creator.save
      render :new, status: :unprocessable_entity
      return
    end

    redirect_to @card, notice: issue_creator.creation_notice
  end

  private
    def load_projects
      @boards = Current.user.boards.alphabetically
    end

    def cactus_issue_params
      params.expect(cactus_issue: [
        :board_id,
        :draft,
        :title,
        :description,
        :priority,
        :problem_description,
        :reproduction_steps,
        :expected_behavior,
        :actual_behavior,
        :environment_context
      ])
    end
end
