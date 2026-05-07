class TrainingExamplesController < ApplicationController
  before_action :ensure_can_review_training_examples
  before_action :set_training_example, only: %i[ show approve reject ]
  before_action :ensure_review_action_allowed, only: %i[ approve reject ]

  def index
    @status = params[:status].presence
    training_examples = Current.account.training_examples.includes(:card, :reviewed_by).order(created_at: :desc)
    training_examples = training_examples.where(status: @status) if TrainingExample.statuses.key?(@status)
    set_page_and_extract_portion_from training_examples
    @training_examples = @page.records
    @approved_export_count = Current.account.training_examples.approved_for_export.count
    @latest_training_example_exports = Current.account.training_example_exports.includes(:user).latest_first.limit(5)
    @exported_without_batch_count = Current.account.training_examples.exported.where(training_example_export_id: nil).count
  end

  def show
    @card_context = @training_example.input_context.fetch("card", {}) || {}
    @board_context = @training_example.input_context.fetch("board", {}) || {}
    @resolution_context = @training_example.input_context.fetch("resolution_record", {}) || {}
    @code_links_context = Array(@training_example.input_context["code_links"])
    @jsonl_preview = JSON.pretty_generate(JSON.parse(TrainingExamples::JsonlExporter.new([ @training_example ]).to_jsonl.lines.first))
  end

  def export
    training_example_export = TrainingExampleExport.queue_for!(account: Current.account, user: Current.user)
    if training_example_export.blank?
      redirect_to training_examples_path, alert: "No approved training examples are ready for export."
      return
    end

    training_example_export.process_later
    AuditEvent.record(
      action: "training_export.queued",
      auditable: training_example_export,
      metadata: {
        training_example_export_id: training_example_export.id,
        example_count: training_example_export.example_count
      }
    )

    redirect_to training_example_exports_path, notice: "JSONL export queued."
  end

  def approve
    @training_example.approve!(reviewer: Current.user, notes: params[:review_notes])
    AuditEvent.record(
      action: "training_example.approved",
      auditable: @training_example,
      metadata: {
        training_example_id: @training_example.id,
        card_id: @training_example.card_id,
        review_notes_present: params[:review_notes].present?
      }
    )

    redirect_to @training_example, notice: "Training example approved."
  end

  def reject
    @training_example.reject!(reviewer: Current.user, notes: params[:review_notes])
    AuditEvent.record(
      action: "training_example.rejected",
      auditable: @training_example,
      metadata: {
        training_example_id: @training_example.id,
        card_id: @training_example.card_id,
        review_notes_present: params[:review_notes].present?
      }
    )

    redirect_to @training_example, notice: "Training example rejected."
  end

  private
    def set_training_example
      @training_example = Current.account.training_examples.includes(:card, :reviewed_by).find(params[:id])
    end

    def ensure_review_action_allowed
      return if @training_example.pending_review? || @training_example.rejected?

      redirect_to @training_example, alert: "Training example has already left review."
    end
end
