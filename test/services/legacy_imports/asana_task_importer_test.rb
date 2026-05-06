require "test_helper"

class LegacyImports::AsanaTaskImporterTest < ActiveSupport::TestCase
  test "maps an Asana task into a legacy card import" do
    result = LegacyImports::AsanaTaskImporter.new(
      account: accounts("37s"),
      board: boards(:writebook),
      creator: users(:david)
    ).import(asana_task)

    assert result.created
    assert_equal "asana", result.resolution_record.legacy_source
    assert_equal "120123", result.resolution_record.legacy_external_id
    assert_equal "Legacy glass issue", result.card.title
    assert_equal "Customer says glass is invisible", result.resolution_record.problem_description
    assert_equal "ES Windows / Glass", result.resolution_record.environment_context
    assert_equal "glass_visibility", result.resolution_record.domain
    assert_equal "Daniel", result.resolution_record.legacy_metadata.dig("created_by", "name")
    assert_equal "Looks fixed", result.resolution_record.legacy_metadata.dig("stories", 0, "text")
    assert_equal "screenshot.png", result.resolution_record.legacy_metadata.dig("attachments", 0, "name")
    assert_equal "imported", result.resolution_record.legacy_metadata.dig("stories", 0, "cactus_comment_import_status")
    assert_includes result.card.comments.last.body.to_plain_text, "Looks fixed"
    assert_equal accounts("37s").system_user, result.card.comments.last.creator
    assert_predicate result.resolution_record, :needs_structuring?
  end

  test "downloads direct Asana attachments into card rich text" do
    downloader = ->(_url, attachment) do
      LegacyImports::AsanaAttachmentImporter::Download.new(
        io: StringIO.new("fake image bytes"),
        filename: attachment["name"],
        content_type: "image/png"
      )
    end

    assert_difference -> { ActiveStorage::Blob.count }, +1 do
      @result = LegacyImports::AsanaTaskImporter.new(
        account: accounts("37s"),
        board: boards(:writebook),
        creator: users(:david),
        attachment_downloader: downloader
      ).import(asana_task.deep_merge(attachments: [
        {
          gid: "attachment-2",
          name: "downloaded.png",
          download_url: "https://asanausercontent.example/downloaded.png",
          permanent_url: "https://app.asana.com/app/asana/-/get_asset?asset_id=attachment-2"
        }
      ]))
    end

    attachment = @result.resolution_record.reload.legacy_metadata.dig("attachments", 0)
    assert_equal "attached", attachment["cactus_attachment_import_status"]
    assert_equal "downloaded.png", attachment["cactus_blob_filename"]
    assert_equal "image/png", attachment["cactus_blob_content_type"]
    assert_equal 1, @result.card.reload.description.body.attachments.size
  end

  test "keeps importing card when direct Asana attachment download fails" do
    downloader = ->(_url, _attachment) { raise "expired URL" }

    result = LegacyImports::AsanaTaskImporter.new(
      account: accounts("37s"),
      board: boards(:writebook),
      creator: users(:david),
      attachment_downloader: downloader
    ).import(asana_task.deep_merge(attachments: [
      {
        gid: "attachment-3",
        name: "expired.png",
        download_url: "https://asanausercontent.example/expired.png"
      }
    ]))

    attachment = result.resolution_record.reload.legacy_metadata.dig("attachments", 0)
    assert result.created
    assert_equal "failed", attachment["cactus_attachment_import_status"]
    assert_match "expired URL", attachment["cactus_attachment_error"]
  end

  test "repeat import can attach files to an existing legacy card without duplicating the card" do
    first_result = LegacyImports::AsanaTaskImporter.new(
      account: accounts("37s"),
      board: boards(:writebook),
      creator: users(:david)
    ).import(asana_task)

    downloader = ->(_url, attachment) do
      LegacyImports::AsanaAttachmentImporter::Download.new(
        io: StringIO.new("fake image bytes"),
        filename: attachment["name"],
        content_type: "image/png"
      )
    end

    assert_difference -> { ActiveStorage::Blob.count }, +1 do
      second_result = LegacyImports::AsanaTaskImporter.new(
        account: accounts("37s"),
        board: boards(:writebook),
        creator: users(:david),
        attachment_downloader: downloader
      ).import(asana_task.deep_merge(attachments: [
        {
          gid: "attachment-1",
          name: "screenshot.png",
          download_url: "https://asanausercontent.example/screenshot.png",
          permanent_url: "https://app.asana.com/app/asana/-/get_asset?asset_id=attachment-1"
        }
      ]))

      assert_not second_result.created
      assert_equal first_result.card, second_result.card
    end

    attachment = first_result.resolution_record.reload.legacy_metadata.dig("attachments", 0)
    assert_equal "attached", attachment["cactus_attachment_import_status"]
    assert_equal 1, first_result.card.reload.description.body.attachments.size
  end

  test "repeat import does not duplicate imported Asana comments" do
    first_result = LegacyImports::AsanaTaskImporter.new(
      account: accounts("37s"),
      board: boards(:writebook),
      creator: users(:david)
    ).import(asana_task)

    assert_no_difference -> { first_result.card.comments.count } do
      second_result = LegacyImports::AsanaTaskImporter.new(
        account: accounts("37s"),
        board: boards(:writebook),
        creator: users(:david)
      ).import(asana_task)

      assert_not second_result.created
    end
  end

  test "imports GitHub links from Asana notes and comments as code evidence" do
    task = asana_task.deep_merge(
      notes: "Fixed by https://github.com/cactuscorp/assemblies/commit/abc1234def5678",
      stories: [
        {
          gid: "story-pr",
          text: "Merged https://github.com/cactuscorp/assemblies/pull/902",
          type: "comment",
          resource_subtype: "comment_added"
        }
      ]
    )

    result = LegacyImports::AsanaTaskImporter.new(
      account: accounts("37s"),
      board: boards(:writebook),
      creator: users(:david)
    ).import(task)

    assert_equal 2, result.card.code_links.count
    assert_equal [ "https://github.com/cactuscorp/assemblies/pull/902" ], result.resolution_record.linked_pr_urls
    assert_equal [ "abc1234def5678" ], result.resolution_record.linked_commit_shas

    pull_request = result.card.code_links.pull_requests.first
    assert_equal "902", pull_request.external_id
    assert_equal "cactuscorp/assemblies", pull_request.repository

    assert_no_difference -> { result.card.code_links.count } do
      LegacyImports::AsanaTaskImporter.new(
        account: accounts("37s"),
        board: boards(:writebook),
        creator: users(:david)
      ).import(task)
    end
  end

  private
    def asana_task
      {
        gid: "120123",
        name: "Legacy glass issue",
        notes: "Customer says glass is invisible",
        completed: true,
        created_at: "2025-01-01T10:00:00Z",
        modified_at: "2025-01-02T10:00:00Z",
        permalink_url: "https://app.asana.com/0/1/120123",
        workspace: { name: "ES Windows" },
        projects: [ { name: "Glass" } ],
        tags: [ { name: "glass_visibility" } ],
        assignee: { name: "Developer" },
        created_by: { name: "Daniel" },
        stories: [
          { gid: "story-1", text: "Looks fixed", type: "comment", resource_subtype: "comment_added" }
        ],
        attachments: [
          { gid: "attachment-1", name: "screenshot.png", permanent_url: "https://app.asana.com/app/asana/-/get_asset?asset_id=attachment-1" }
        ]
      }
    end
end
