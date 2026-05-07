class LegacyImports::AsanasController < ApplicationController
  before_action :ensure_can_import_cactus_issues

  def new
    @boards = Current.user.boards.order(:name)
    @recent_imports = recent_imports
  end

  def create
    @boards = Current.user.boards.order(:name)
    @board = @boards.find(params.expect(:board_id))
    @asana_import = build_import
    @asana_import.save!
    @asana_import.process_later
    AuditEvent.record(
      action: "legacy_asana_import.queued",
      auditable: @asana_import,
      metadata: {
        asana_import_id: @asana_import.id,
        project_id: @board.id,
        filename: @asana_import.file.attached? ? @asana_import.file.filename.to_s : nil
      }
    )

    redirect_to legacy_imports_asana_import_path(@asana_import, script_name: request.script_name), notice: "Asana import queued."
  rescue ActionController::ParameterMissing, ActiveRecord::RecordInvalid => error
    @recent_imports = recent_imports
    flash.now[:alert] = "Asana import failed: #{failure_message(error)}"
    render :new, status: :unprocessable_entity
  end

  private
    def build_import
      Current.account.legacy_asana_imports.build(board: @board, creator: Current.user).tap do |asana_import|
        asana_import.file.attach(file)
      end
    end

    def file
      params.expect(:file)
    end

    def recent_imports
      Current.account.legacy_asana_imports.includes(:board, :creator, file_attachment: :blob).latest_first.limit(5)
    end

    def failure_message(error)
      error.message.to_s.scrub
    end
end
