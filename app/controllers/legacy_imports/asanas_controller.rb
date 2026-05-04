class LegacyImports::AsanasController < ApplicationController
  before_action :ensure_can_import_cactus_issues

  def new
    @boards = Current.user.boards.order(:name)
  end

  def create
    @boards = Current.user.boards.order(:name)
    @board = @boards.find(params.expect(:board_id))
    @summary = import_tasks

    render :new, status: :created
  rescue JSON::ParserError, ActionController::ParameterMissing, ActiveRecord::RecordInvalid => error
    @summary = nil
    flash.now[:alert] = "Asana import failed: #{failure_message(error)}"
    render :new, status: :unprocessable_entity
  end

  private
    def import_tasks
      tasks = parse_tasks
      importer = LegacyImports::AsanaTaskImporter.new(account: Current.account, board: @board, creator: Current.user)
      results = tasks.map { importer.import(it) }

      {
        total: results.size,
        created: results.count(&:created),
        skipped: results.count { !it.created },
        needs_structuring: results.count { it.resolution_record.needs_structuring? }
      }
    end

    def parse_tasks
      payload = JSON.parse(file.read)
      tasks = payload.is_a?(Hash) ? payload["data"] : payload

      raise JSON::ParserError, "expected an array of Asana tasks or an object with a data array" unless tasks.is_a?(Array)

      tasks
    end

    def file
      params.expect(:file)
    end

    def failure_message(error)
      if error.is_a?(JSON::ParserError)
        "invalid JSON file"
      else
        error.message.to_s.scrub
      end
    end
end
