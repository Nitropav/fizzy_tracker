module LegacyImports
  class AsanaImport < ApplicationRecord
    self.table_name = "legacy_imports_asana_imports"

    STATUSES = %w[ pending processing completed completed_with_errors failed ].freeze

    belongs_to :account
    belongs_to :board
    belongs_to :creator, class_name: "User"

    has_one_attached :file, dependent: :purge_later

    enum :status, STATUSES.index_by(&:itself), default: :pending

    scope :latest_first, -> { order(created_at: :desc, id: :desc) }

    validates :account, :board, :creator, :status, presence: true
    validate :file_attached
    validate :board_belongs_to_account
    validate :creator_belongs_to_account

    def process_later
      LegacyImports::AsanaImportJob.perform_later(self)
    end

    def retryable?
      failed? && file.attached?
    end

    def retry_later!
      raise "Only failed Asana imports with an uploaded file can be retried." unless retryable?

      reset_for_retry!
      process_later
    end

    def process!
      return self if completed? || completed_with_errors?

      update!(status: :processing, started_at: Time.current, error_message: nil)

      tasks = parse_tasks
      update!(total_count: tasks.size)

      importer = LegacyImports::AsanaTaskImporter.new(account: account, board: board, creator: creator)
      results = []
      failures = []

      tasks.each_with_index do |task, index|
        results << importer.import(task)
      rescue => error
        failures << task_failure_message(index, task, error)
      end

      update!(
        status: failures.any? ? :completed_with_errors : :completed,
        created_count: results.count(&:created),
        skipped_count: results.count { !it.created },
        needs_structuring_count: results.count { it.resolution_record.needs_structuring? },
        failed_count: failures.size,
        error_message: failures.first(5).join("\n").presence,
        completed_at: Time.current
      )

      self
    rescue => error
      update!(
        status: :failed,
        error_message: failure_message(error),
        completed_at: Time.current
      )

      self
    end

    def finished?
      completed? || completed_with_errors? || failed?
    end

    private
      def reset_for_retry!
        update!(
          status: :pending,
          started_at: nil,
          completed_at: nil,
          error_message: nil,
          total_count: 0,
          created_count: 0,
          skipped_count: 0,
          needs_structuring_count: 0,
          failed_count: 0
        )
      end

      def parse_tasks
        payload = JSON.parse(file.download)
        tasks = tasks_from(payload)

        raise JSON::ParserError, "expected an array of Asana tasks or an object with a data/tasks array" unless tasks.is_a?(Array)

        tasks
      end

      def tasks_from(payload)
        return payload unless payload.is_a?(Hash)

        payload["data"] || payload["tasks"]
      end

      def task_failure_message(index, task, error)
        task = task.to_h.deep_stringify_keys if task.respond_to?(:to_h)
        external_id = task["gid"] if task.respond_to?(:[])
        label = external_id.present? ? "task #{external_id}" : "task ##{index + 1}"

        "#{label}: #{failure_message(error)}"
      end

      def failure_message(error)
        if error.is_a?(JSON::ParserError)
          "invalid JSON file"
        else
          error.message.to_s.scrub.truncate(500)
        end
      end

      def file_attached
        errors.add(:file, "must be attached") unless file.attached?
      end

      def board_belongs_to_account
        return if account.blank? || board.blank? || board.account_id == account_id

        errors.add(:board, "must belong to the import account")
      end

      def creator_belongs_to_account
        return if account.blank? || creator.blank? || creator.account_id == account_id

        errors.add(:creator, "must belong to the import account")
      end
  end
end
