module LegacyImports
  class AsanaTaskImporter
    def initialize(account:, board:, creator:, attachment_downloader: nil)
      @card_importer = CardImporter.new(account: account, board: board, creator: creator)
      @attachment_downloader = attachment_downloader
    end

    def import(task)
      task = task.to_h.deep_stringify_keys

      result = card_importer.import(
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

      import_attachments_for(result, incoming_attachments: task["attachments"])
      import_comments_for(result, incoming_stories: task["stories"])
      import_code_links_for(result, task: task)
      result
    end

    private
      attr_reader :card_importer, :attachment_downloader

      def import_attachments_for(result, incoming_attachments:)
        attachments = attachments_for_import(
          existing_attachments: result.resolution_record.legacy_metadata["attachments"],
          incoming_attachments: incoming_attachments
        )
        return if attachments.blank?

        attachment_result = AsanaAttachmentImporter.new(
          card: result.card,
          downloader: attachment_downloader
        ).import(attachments)

        result.resolution_record.update!(
          legacy_metadata: result.resolution_record.legacy_metadata.merge(
            "attachments" => attachment_result.attachments
          )
        )
      end

      def import_comments_for(result, incoming_stories:)
        stories = stories_for_import(
          existing_stories: result.resolution_record.legacy_metadata["stories"],
          incoming_stories: incoming_stories
        )
        return if stories.blank?

        comment_result = AsanaCommentImporter.new(card: result.card).import(stories)

        result.resolution_record.update!(
          legacy_metadata: result.resolution_record.legacy_metadata.merge(
            "stories" => comment_result.stories
          )
        )
      end

      def import_code_links_for(result, task:)
        code_link_result = GithubCodeLinkImporter.new(card: result.card).import(github_reference_texts_from(task))
        return if code_link_result.code_links.empty?

        result.resolution_record.update!(
          linked_pr_urls: (result.resolution_record.linked_pr_urls + code_link_result.pull_request_urls).uniq,
          linked_commit_shas: (result.resolution_record.linked_commit_shas + code_link_result.commit_shas).uniq
        )
      end

      def attachments_for_import(existing_attachments:, incoming_attachments:)
        existing_attachments = Array(existing_attachments).select { it.is_a?(Hash) }
        incoming_attachments = Array(incoming_attachments).select { it.is_a?(Hash) }
        return existing_attachments if incoming_attachments.blank?

        existing_by_key = existing_attachments.index_by { attachment_key(it) }

        incoming_attachments.map do |incoming_attachment|
          existing_attachment = existing_by_key[attachment_key(incoming_attachment)]
          next incoming_attachment if existing_attachment.blank?

          if existing_attachment["cactus_blob_signed_id"].present?
            incoming_attachment.merge(existing_attachment.slice(*cactus_attachment_metadata_keys))
          else
          existing_attachment.merge(incoming_attachment)
          end
        end
      end

      def stories_for_import(existing_stories:, incoming_stories:)
        existing_stories = Array(existing_stories).select { it.is_a?(Hash) }
        incoming_stories = Array(incoming_stories).select { it.is_a?(Hash) }
        return existing_stories if incoming_stories.blank?

        existing_by_key = existing_stories.index_by { story_key(it) }

        incoming_stories.map do |incoming_story|
          existing_story = existing_by_key[story_key(incoming_story)]
          next incoming_story if existing_story.blank?

          if existing_story["cactus_comment_id"].present?
            incoming_story.merge(existing_story.slice(*cactus_comment_metadata_keys))
          else
            existing_story.merge(incoming_story)
          end
        end
      end

      def attachment_key(attachment)
        attachment["gid"].presence ||
          attachment["download_url"].presence ||
          attachment["view_url"].presence ||
          attachment["permanent_url"].presence ||
          attachment["name"].to_s
      end

      def cactus_attachment_metadata_keys
        %w[
          cactus_attachment_import_status
          cactus_attachment_error
          cactus_blob_signed_id
          cactus_blob_filename
          cactus_blob_content_type
          cactus_blob_byte_size
        ]
      end

      def story_key(story)
        story["gid"].presence ||
          story["created_at"].presence ||
          story["text"].to_s
      end

      def cactus_comment_metadata_keys
        %w[
          cactus_comment_import_status
          cactus_comment_import_error
          cactus_comment_id
        ]
      end

      def github_reference_texts_from(task)
        [
          task["notes"],
          *Array(task["stories"]).filter_map { story_texts_from(it) }
        ].flatten.compact_blank
      end

      def story_texts_from(story)
        return unless story.is_a?(Hash)

        [ story["text"], story["html_text"] ]
      end

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
