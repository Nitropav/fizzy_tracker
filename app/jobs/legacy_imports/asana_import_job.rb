module LegacyImports
  class AsanaImportJob < ApplicationJob
    queue_as :backend

    discard_on ActiveJob::DeserializationError

    def perform(asana_import)
      asana_import.process!
    end
  end
end
