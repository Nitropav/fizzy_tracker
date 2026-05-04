class LegacyImports::AsanaTrainingExamplesController < ApplicationController
  before_action :ensure_can_import_cactus_issues
  before_action :set_resolution_record

  def create
    unless @resolution_record.legacy_training_candidate_ready?
      redirect_to legacy_imports_asana_issues_path(status: "needs_structuring"), alert: incomplete_message
      return
    end

    training_example = TrainingExamples::Generator.new(@resolution_record.card).generate
    redirect_to success_redirect_path(training_example), notice: "Training example candidate generated from legacy Asana issue."
  rescue TrainingExamples::Generator::MissingResolutionRecord,
    TrainingExamples::Generator::IncompleteGateOne,
    TrainingExamples::Generator::IncompleteGateTwo => error
    redirect_to legacy_imports_asana_issues_path(status: "needs_structuring"), alert: error.message
  end

  private
    def set_resolution_record
      @resolution_record = Card::ResolutionRecord.find_by!(
        id: params[:issue_id],
        account: Current.account,
        legacy_import: true,
        legacy_source: "asana"
      )
    end

    def incomplete_message
      blockers = @resolution_record.legacy_training_candidate_blockers
      if blockers.any?
        "Complete legacy issue structure before generating a training example. Missing: #{blockers.to_sentence}."
      else
        "Complete legacy issue structure before generating a training example."
      end
    end

    def success_redirect_path(training_example)
      if Current.user.can_review_training_examples?
        training_example_path(training_example)
      else
        legacy_imports_asana_issues_path(status: "structured")
      end
    end
end
