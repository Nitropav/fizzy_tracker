class LegacyImports::AsanaIssuesController < ApplicationController
  before_action :ensure_can_import_cactus_issues

  STATUSES = %w[ needs_structuring structured training_candidates all ].freeze

  def index
    @status = params[:status].presence_in(STATUSES) || "needs_structuring"
    @counts = status_counts

    set_page_and_extract_portion_from filtered_records
      .includes(card: [ :board, :column, :ai_runs, :training_examples ])
      .order(legacy_imported_at: :desc, created_at: :desc)
    @records = @page.records
  end

  private
    def base_records
      Card::ResolutionRecord.where(
        account: Current.account,
        legacy_import: true,
        legacy_source: "asana"
      )
    end

    def filtered_records
      case @status
      when "needs_structuring"
        base_records.where(needs_structuring: true)
      when "structured"
        base_records.where(needs_structuring: false)
      when "training_candidates"
        base_records.legacy_training_candidates
      else
        base_records
      end
    end

    def status_counts
      {
        "needs_structuring" => base_records.where(needs_structuring: true).count,
        "structured" => base_records.where(needs_structuring: false).count,
        "training_candidates" => base_records.legacy_training_candidates.count,
        "all" => base_records.count
      }
    end
end
