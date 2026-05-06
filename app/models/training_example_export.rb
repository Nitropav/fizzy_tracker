class TrainingExampleExport < ApplicationRecord
  STATUSES = %w[ pending processing completed failed ].freeze

  belongs_to :account
  belongs_to :user

  has_one_attached :file, dependent: :purge_later

  enum :status, STATUSES.index_by(&:itself), default: :pending

  attribute :training_example_ids, default: -> { [] }

  validates :filename, presence: true
  validates :example_count, numericality: { greater_than_or_equal_to: 0 }
  validates :completed_at, presence: true, if: :completed?
  validate :user_matches_account

  scope :latest_first, -> { order(created_at: :desc, id: :desc) }

  def self.queue_for!(account:, user:)
    transaction do
      training_examples = account.training_examples.approved_for_export.order(:created_at, :id).lock.to_a
      return nil if training_examples.empty?

      export = account.training_example_exports.create!(
        user: user,
        status: :pending,
        filename: filename_for(Time.current),
        example_count: training_examples.size,
        training_example_ids: training_examples.map(&:id)
      )

      TrainingExample.where(id: training_examples.map(&:id)).update_all(
        training_example_export_id: export.id,
        updated_at: Time.current
      )

      export
    end
  end

  def training_examples
    examples_by_id = account.training_examples.where(id: training_example_ids).index_by(&:id)

    training_example_ids.filter_map { examples_by_id[it] }
  end

  def process_later
    TrainingExamples::ExportJob.perform_later(self)
  end

  def process!
    return self if completed?

    update!(status: :processing, started_at: Time.current, error_message: nil)

    exported_at = Time.current
    examples = training_examples
    raise "No training examples are reserved for this export." if examples.empty?

    payload = TrainingExamples::JsonlExporter.new(examples, exported_at: exported_at).to_jsonl

    transaction do
      file.attach(
        io: StringIO.new(payload),
        filename: filename,
        content_type: "application/jsonl"
      )

      examples.each { it.mark_exported!(training_example_export: self, exported_at: exported_at) }

      update!(
        status: :completed,
        example_count: examples.size,
        completed_at: exported_at
      )
    end

    self
  rescue => error
    release_reserved_examples
    update!(
      status: :failed,
      error_message: error.message.to_s.scrub.truncate(500),
      completed_at: Time.current
    )

    self
  end

  def downloadable?
    completed?
  end

  private
    def self.filename_for(time)
      "training-examples-#{time.utc.strftime('%Y%m%d%H%M%S')}.jsonl"
    end

    def user_matches_account
      return if user.blank? || account.blank? || user.account_id == account_id

      errors.add(:user, "must belong to the export account")
    end

    def release_reserved_examples
      account.training_examples
        .where(id: training_example_ids, status: :approved, training_example_export_id: id)
        .update_all(training_example_export_id: nil, updated_at: Time.current)
    end
end
