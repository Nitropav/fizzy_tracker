require "net/http"
require "tempfile"

module LegacyImports
  class AsanaAttachmentImporter
    Download = Data.define(:io, :filename, :content_type)
    Result = Data.define(:attachments, :attached_count, :failed_count, :skipped_count)

    MAX_BYTES = 10.megabytes
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 15

    def initialize(card:, downloader: nil, max_bytes: MAX_BYTES)
      @card = card
      @downloader = downloader || method(:download)
      @max_bytes = max_bytes
    end

    def import(attachments)
      imported_attachments = Array(attachments).map { import_one(it.to_h.deep_stringify_keys) }

      Result.new(
        imported_attachments,
        imported_attachments.count { it["cactus_attachment_import_status"] == "attached" },
        imported_attachments.count { it["cactus_attachment_import_status"] == "failed" },
        imported_attachments.count { it["cactus_attachment_import_status"] == "skipped" }
      )
    end

    private
      attr_reader :card, :downloader, :max_bytes

      def import_one(attachment)
        return attachment if attachment["cactus_blob_signed_id"].present?

        url = downloadable_url(attachment)
        return mark_skipped(attachment, "No direct Asana download URL") if url.blank?

        download = nil
        download = downloader.call(url, attachment)
        return mark_skipped(attachment, "Downloader returned no file") if download.blank?

        blob = create_blob(download, attachment)
        append_blob_to_card_description(blob)
        mark_attached(attachment, blob)
      rescue => error
        mark_failed(attachment, error)
      ensure
        close_download(download) if download
      end

      def downloadable_url(attachment)
        attachment["download_url"].presence || attachment["view_url"].presence
      end

      def create_blob(download, attachment)
        Current.with(account: card.account) do
          download.io.rewind if download.io.respond_to?(:rewind)

          ActiveStorage::Blob.create_and_upload!(
            io: download.io,
            filename: download.filename.presence || attachment["name"].presence || "asana-attachment",
            content_type: download.content_type.presence || "application/octet-stream"
          )
        end
      end

      def append_blob_to_card_description(blob)
        current_html = card.description&.body&.to_html.to_s
        card.update!(
          description: [
            current_html,
            attachment_html_for(blob)
          ].compact_blank.join("\n")
        )
      end

      def attachment_html_for(blob)
        <<~HTML.squish
          <action-text-attachment
            sgid="#{ERB::Util.html_escape(blob.attachable_sgid)}"
            content-type="#{ERB::Util.html_escape(blob.content_type)}"
            filename="#{ERB::Util.html_escape(blob.filename.to_s)}"
            filesize="#{blob.byte_size}">
          </action-text-attachment>
        HTML
      end

      def mark_attached(attachment, blob)
        attachment.except("cactus_attachment_error").merge(
          "cactus_attachment_import_status" => "attached",
          "cactus_blob_signed_id" => blob.signed_id,
          "cactus_blob_filename" => blob.filename.to_s,
          "cactus_blob_content_type" => blob.content_type,
          "cactus_blob_byte_size" => blob.byte_size
        )
      end

      def mark_failed(attachment, error)
        attachment.merge(
          "cactus_attachment_import_status" => "failed",
          "cactus_attachment_error" => error.message.to_s.truncate(240)
        )
      end

      def mark_skipped(attachment, reason)
        attachment.merge(
          "cactus_attachment_import_status" => "skipped",
          "cactus_attachment_error" => reason
        )
      end

      def close_download(download)
        download.io.close if download.io.respond_to?(:close)
        download.io.unlink if download.io.respond_to?(:unlink)
      end

      def download(url, attachment, redirects: 3)
        raise ArgumentError, "too many redirects" if redirects.negative?

        uri = URI.parse(url)
        raise ArgumentError, "unsupported attachment URL scheme" unless uri.is_a?(URI::HTTP)

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          request = Net::HTTP::Get.new(uri)
          request["User-Agent"] = "Cactus Asana Attachment Importer"

          http.request(request) do |response|
            if response.is_a?(Net::HTTPRedirection) && response["location"].present?
              return download(URI.join(uri, response["location"]).to_s, attachment, redirects: redirects - 1)
            end

            raise ArgumentError, "download failed with #{response.code}" unless response.is_a?(Net::HTTPSuccess)

            content_type = response["content-type"].to_s.split(";").first.presence || content_type_from_name(attachment["name"])
            tempfile = Tempfile.new([ "asana-attachment", File.extname(attachment["name"].to_s) ], binmode: true)
            bytes = 0

            response.read_body do |chunk|
              bytes += chunk.bytesize
              raise ArgumentError, "attachment exceeds #{max_bytes} bytes" if bytes > max_bytes

              tempfile.write(chunk)
            end

            tempfile.rewind
            return Download.new(
              io: tempfile,
              filename: attachment["name"].presence || filename_from_uri(uri),
              content_type: content_type
            )
          end
        end
      end

      def filename_from_uri(uri)
        File.basename(uri.path).presence || "asana-attachment"
      end

      def content_type_from_name(name)
        Marcel::MimeType.for(Pathname.new(name.to_s), name: name.to_s)
      end
  end
end
