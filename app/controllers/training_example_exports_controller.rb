class TrainingExampleExportsController < ApplicationController
  before_action :ensure_can_review_training_examples
  before_action :set_training_example_export, only: :show

  def index
    @training_example_exports = Current.account.training_example_exports.includes(:user).latest_first
    @exported_without_batch_count = Current.account.training_examples.exported.where(training_example_export_id: nil).count
  end

  def show
    send_data(
      TrainingExamples::JsonlExporter.new(@training_example_export.training_examples, exported_at: @training_example_export.completed_at).to_jsonl,
      filename: @training_example_export.filename,
      type: "application/jsonl; charset=utf-8",
      disposition: "attachment"
    )
  end

  private
    def set_training_example_export
      @training_example_export = Current.account.training_example_exports.find(params[:id])
    end
end
