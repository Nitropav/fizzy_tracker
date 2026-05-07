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
        if (existing_comment = existing_imported_comment(story))
          return mark_imported(story, existing_comment)
        end

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

      def existing_imported_comment(story)
        comment_id = story["cactus_comment_id"]
        if comment_id.present? && (comment = card.comments.find_by(id: comment_id))
          return comment
        end

        find_existing_imported_comment_by_body(story)
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

      def find_existing_imported_comment_by_body(story)
        comment_text = normalized_comment_text(story["text"])
        return if comment_text.blank?

        author = normalized_comment_text(story_author(story))
        timestamp = parse_time(story["created_at"])
        timestamp_text = normalized_comment_text(timestamp&.to_fs(:db))

        card.comments.preloaded.find do |comment|
          body = normalized_comment_text(comment.body.to_plain_text)
          body.include?("imported asana comment") &&
            body.include?(comment_text) &&
            (author.blank? || body.include?(author)) &&
            (timestamp_text.blank? || body.include?(timestamp_text))
        end
      end

      def normalized_comment_text(value)
        value.to_s.squish.downcase
      end
  end
end
