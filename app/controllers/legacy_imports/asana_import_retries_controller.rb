class LegacyImports::AsanaImportRetriesController < ApplicationController
  before_action :ensure_can_import_cactus_issues

  def create
    @asana_import = Current.account.legacy_asana_imports.find(params[:asana_import_id])

    if @asana_import.retryable?
      @asana_import.retry_later!
      AuditEvent.record(
        action: "legacy_asana_import.retried",
        auditable: @asana_import,
        metadata: {
          asana_import_id: @asana_import.id,
          project_id: @asana_import.board_id
        }
      )
      redirect_to legacy_imports_asana_import_path(@asana_import, script_name: request.script_name), notice: "Asana import retry queued."
    else
      redirect_to legacy_imports_asana_import_path(@asana_import, script_name: request.script_name), alert: "Only failed Asana imports with an uploaded JSON file can be retried."
    end
  end
end
