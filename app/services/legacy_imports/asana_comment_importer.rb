module LegacyImports
  class AsanaCommentImporter
    Result = Data.define(:stories, :imported_count, :failed_count, :skipped_count)

    def initialize(card:)
      @card = card
    end

    def import(stories)
      imported_stories = Array(stories).map { import_one(it.to_h.deep_stringify_keys) }

      Result.new(
        imported_stories,
        imported_stories.count { it["cactus_comment_import_status"] == "imported" },
        imported_stories.count { it["cactus_comment_import_status"] == "failed" },
        imported_stories.count { it["cactus_comment_import_status"] == "skipped" }
      )
    end

    private
      attr_reader :card

      def import_one(story)
        return story unless comment_story?(story)
        return mark_skipped(story, "Empty Asana comment") if story["text"].blank?
        return story if imported_comment_exists?(story)

        comment = Current.with(account: card.account, user: card.account.system_user, identity: nil) do
          card.comments.create!(
            creator: card.account.system_user,
            body: comment_body_for(story),
            created_at: parse_time(story["created_at"]) || Time.current
          )
        end

        mark_imported(story, comment)
      rescue => error
        mark_failed(story, error)
      end

      def imported_comment_exists?(story)
        comment_id = story["cactus_comment_id"]
        comment_id.present? && card.comments.exists?(id: comment_id)
      end

      def comment_body_for(story)
        author = story_author(story)
        timestamp = parse_time(story["created_at"])
        imported_at = timestamp ? " on #{ERB::Util.html_escape(timestamp.to_fs(:db))}" : nil
        escaped_text = ERB::Util.html_escape(story["text"].to_s).gsub(/\r?\n/, "<br>")

        <<~HTML.squish
          <p><strong>Imported Asana comment</strong> from #{ERB::Util.html_escape(author)}#{imported_at}</p>
          <blockquote>#{escaped_text}</blockquote>
        HTML
      end

      def story_author(story)
        author = story["created_by"].is_a?(Hash) ? story["created_by"] : {}
        author["name"].presence || author["email"].presence || "Asana user"
      end

      def mark_imported(story, comment)
        story.except("cactus_comment_import_error").merge(
          "cactus_comment_import_status" => "imported",
          "cactus_comment_id" => comment.id
        )
      end

      def mark_failed(story, error)
        story.merge(
          "cactus_comment_import_status" => "failed",
          "cactus_comment_import_error" => error.message.to_s.truncate(240)
        )
      end

      def mark_skipped(story, reason)
        story.merge(
          "cactus_comment_import_status" => "skipped",
          "cactus_comment_import_error" => reason
        )
      end

      def comment_story?(story)
        story["type"] == "comment" || story["resource_subtype"] == "comment_added"
      end

      def parse_time(value)
        Time.zone.parse(value) if value.present?
      end
  end
end
