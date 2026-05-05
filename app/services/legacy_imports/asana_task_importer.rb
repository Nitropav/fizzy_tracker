module LegacyImports
  class AsanaTaskImporter
    def initialize(account:, board:, creator:)
      @card_importer = CardImporter.new(account: account, board: board, creator: creator)
    end

    def import(task)
      task = task.to_h.deep_stringify_keys

      card_importer.import(
        source: "asana",
        external_id: task.fetch("gid"),
        title: task["name"],
        description: task["notes"],
        fields: fields_from(task),
        metadata: metadata_from(task),
        resolved: task["completed"],
        created_at: parse_time(task["created_at"]),
        updated_at: parse_time(task["modified_at"])
      )
    end

    private
      attr_reader :card_importer

      def fields_from(task)
        {
          problem_description: task["notes"].presence || task["name"],
          environment_context: environment_context(task),
          structured_summary: task["name"],
          category: "legacy",
          domain: domain(task)
        }.compact
      end

      def metadata_from(task)
        task.slice(
          "gid",
          "permalink_url",
          "completed",
          "completed_at",
          "created_at",
          "modified_at",
          "workspace",
          "project_gid",
          "projects",
          "memberships",
          "assignee",
          "created_by",
          "followers",
          "due_at",
          "due_on",
          "num_subtasks",
          "parent",
          "resource_subtype",
          "tags",
          "custom_fields",
          "stories",
          "attachments"
        )
      end

      def environment_context(task)
        project_names = Array(task["projects"]).filter_map { it["name"] if it.respond_to?(:[]) }
        workspace_name = task.dig("workspace", "name")

        [ workspace_name, *project_names ].compact_blank.join(" / ").presence
      end

      def domain(task)
        Array(task["tags"]).filter_map { it["name"] if it.respond_to?(:[]) }.first
      end

      def parse_time(value)
        Time.zone.parse(value) if value.present?
      end
  end
end
