class TrainingExamplesController < ApplicationController
  before_action :ensure_admin
  before_action :set_training_example, only: %i[ show approve reject ]

  def index
    @status = params[:status].presence
    @training_examples = Current.account.training_examples.includes(:card, :reviewed_by).order(created_at: :desc)
    @training_examples = @training_examples.where(status: @status) if TrainingExample.statuses.key?(@status)
  end

  def show
  end

  def export
    training_examples = Current.account.training_examples.approved_for_export.includes(:card, :reviewed_by).order(:created_at).to_a
    payload = TrainingExamples::JsonlExporter.new(training_examples).to_jsonl

    TrainingExample.transaction do
      training_examples.each(&:mark_exported!)
    end

    send_data(
      payload,
      filename: "training-examples-#{Time.current.utc.strftime('%Y%m%d%H%M%S')}.jsonl",
      type: "application/jsonl; charset=utf-8",
      disposition: "attachment"
    )
  end

  def approve
    @training_example.approve!(reviewer: Current.user, notes: params[:review_notes])

    redirect_to @training_example, notice: "Training example approved."
  end

  def reject
    @training_example.reject!(reviewer: Current.user, notes: params[:review_notes])

    redirect_to @training_example, notice: "Training example rejected."
  end

  private
    def set_training_example
      @training_example = Current.account.training_examples.includes(:card, :reviewed_by).find(params[:id])
    end
end
