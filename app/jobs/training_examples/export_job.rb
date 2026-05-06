module TrainingExamples
  class ExportJob < ApplicationJob
    queue_as :backend

    discard_on ActiveJob::DeserializationError

    def perform(training_example_export)
      training_example_export.process!
    end
  end
end
