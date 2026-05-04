require "test_helper"

class Cards::ResolutionRecordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
    @card = cards(:logo)
  end

  test "update creates resolution record for card" do
    assert_difference -> { Card::ResolutionRecord.count }, +1 do
      put card_resolution_record_path(@card), params: {
        card_resolution_record: {
          problem_description: "Logo is unreadable",
          reproduction_steps: "Open the card",
          expected_behavior: "Logo should be readable",
          actual_behavior: "Logo is too small",
          environment_context: "Fizzy card page"
        }
      }, as: :turbo_stream
    end

    assert_response :success
    assert @card.reload.resolution_record.gate_one_complete?
  end

  test "reporter cannot update gate two fields" do
    users(:david).update!(cactus_role: :reporter)
    logout_and_sign_in_as :david

    put card_resolution_record_path(@card), params: {
      card_resolution_record: {
        root_cause: "Should not save"
      }
    }, as: :json

    assert_response :forbidden
    assert_nil @card.reload.resolution_record
  end

  test "developer cannot update queue classification fields" do
    logout_and_sign_in_as :david
    @card.create_resolution_record!(problem_description: "Logo is unreadable")

    put card_resolution_record_path(@card), params: {
      card_resolution_record: {
        category: "bug"
      }
    }, as: :json

    assert_response :forbidden
    assert_nil @card.reload.resolution_record.category
  end

  test "support can update queue classification fields" do
    logout_and_sign_in_as :jz
    @card.create_resolution_record!(problem_description: "Logo is unreadable")

    put card_resolution_record_path(@card), params: {
      card_resolution_record: {
        priority: "urgent",
        category: "bug"
      }
    }, as: :json

    assert_response :success
    assert_equal "urgent", @card.reload.resolution_record.priority
    assert_equal "bug", @card.reload.resolution_record.category
  end

  test "turbo update renders refreshed cactus workflow state" do
    card = cards(:buy_domain)
    card.create_resolution_record!(problem_description: "Domain purchase is blocked")

    put card_resolution_record_path(card), params: {
      card_resolution_record: {
        reproduction_steps: "Open settings",
        expected_behavior: "Domain can be purchased",
        actual_behavior: "Purchase button is disabled",
        environment_context: "Account settings"
      }
    }, as: :turbo_stream

    assert_response :success
    assert_includes response.body, "State: Open"
    assert_includes response.body, "Gate 1: Complete"
    assert_no_match "Gate 1 missing", response.body
  end

  test "edit renders focused gate two form" do
    @card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small",
      environment_context: "Fizzy card page"
    )
    @card.code_links.create!(
      provider: "github",
      external_type: "commit",
      external_id: "abc123",
      repository: "cactus/fizzy",
      sha: "abc1234567890",
      title: "Fix logo rendering",
      url: "https://github.com/cactus/fizzy/commit/abc123",
      metadata: {}
    )

    get edit_card_resolution_record_path(@card)

    assert_response :success
    assert_select "h1", text: "Gate 2 resolution"
    assert_select "textarea[name='card_resolution_record[root_cause]']"
    assert_select "textarea[name='card_resolution_record[fix_summary]']"
    assert_select "textarea[name='card_resolution_record[verification_steps]']"
    assert_match "Logo is unreadable", response.body
    assert_match "Linked code evidence", response.body
    assert_match "Fix logo rendering", response.body
    assert_select "a[href=?]", "https://github.com/cactus/fizzy/commit/abc123", text: "Open"
  end

  test "update from focused gate two form redirects back to gate two page" do
    @card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small",
      environment_context: "Fizzy card page"
    )

    put card_resolution_record_path(@card), params: {
      return_to: "gate_two",
      card_resolution_record: {
        root_cause: "Wrong image dimensions",
        fix_summary: "Adjusted the logo size",
        verification_steps: "Opened the card and checked the logo",
        linked_commit_shas: [ "abc123\ndef456" ],
        linked_pr_urls: [ "https://github.com/basecamp/fizzy/pull/123" ]
      }
    }

    assert_redirected_to edit_card_resolution_record_path(@card)
    assert_equal "Training data saved.", flash[:notice]
    assert @card.resolution_record.reload.gate_two_complete?
    assert_equal [ "abc123", "def456" ], @card.resolution_record.linked_commit_shas
  end

  test "edit does not show resolve action before issue is in review state" do
    card = cards(:buy_domain)
    card.create_resolution_record!(
      problem_description: "Domain purchase is blocked",
      reproduction_steps: "Open settings",
      expected_behavior: "Domain can be purchased",
      actual_behavior: "Purchase button is disabled",
      environment_context: "Account settings",
      root_cause: "Missing billing setup",
      fix_summary: "Added billing setup",
      verification_steps: "Opened settings and confirmed purchase button"
    )

    get edit_card_resolution_record_path(card)

    assert_response :success
    assert_match "Gate 2 complete", response.body
    assert_match "Move this issue into active work before resolving it.", response.body
    assert_no_match "Ready to resolve", response.body
    assert_select "form[action=?]", card_resolution_path(card), count: 0
  end

  test "edit shows resolve action when issue needs review" do
    @card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small",
      environment_context: "Fizzy card page",
      root_cause: "Wrong image dimensions",
      fix_summary: "Adjusted the logo size",
      verification_steps: "Opened the card and checked the logo",
      linked_commit_shas: [ "abc123" ]
    )

    get edit_card_resolution_record_path(@card)

    assert_response :success
    assert_match "Ready to resolve", response.body
    assert_select "form[action=?]", card_resolution_path(@card)
  end

  test "edit hides resolve action after issue is resolved" do
    @card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small",
      environment_context: "Fizzy card page",
      root_cause: "Wrong image dimensions",
      fix_summary: "Adjusted the logo size",
      verification_steps: "Opened the card and checked the logo",
      linked_commit_shas: [ "abc123" ]
    )
    @card.resolve(user: users(:kevin))

    get edit_card_resolution_record_path(@card)

    assert_response :success
    assert_match "Issue already resolved", response.body
    assert_no_match "Ready to resolve", response.body
    assert_select "form[action=?]", card_resolution_path(@card), count: 0
  end

  test "update from cactus queue redirects back to queue state" do
    @card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small",
      environment_context: "Fizzy card page"
    )

    put card_resolution_record_path(@card), params: {
      return_to: "cactus_queue",
      queue_state: "open",
      card_resolution_record: {
        priority: "high",
        category: "bug",
        domain: "visual design",
        severity: "degrades experience"
      }
    }

    assert_redirected_to cactus_queues_path(state: "open")
    assert_equal "high", @card.resolution_record.reload.priority
    assert_equal "bug", @card.resolution_record.reload.category
    assert_equal "visual design", @card.resolution_record.domain
    assert_equal "degrades experience", @card.resolution_record.severity
  end

  test "update modifies existing resolution record" do
    record = @card.create_resolution_record!(problem_description: "Old problem")

    put card_resolution_record_path(@card), params: {
      card_resolution_record: {
        problem_description: "Updated problem",
        reproduction_steps: "Open the card",
        expected_behavior: "Logo should be readable",
        actual_behavior: "Logo is too small",
        environment_context: "Fizzy card page",
        linked_commit_shas: [ "abc123, def456" ]
      }
    }, as: :json

    assert_response :success
    assert_equal "Updated problem", record.reload.problem_description
    assert_equal [ "abc123", "def456" ], record.linked_commit_shas
  end

  test "update marks unresolved legacy record structured when gate one is complete" do
    record = @card.create_resolution_record!(
      legacy_import: true,
      legacy_source: "asana",
      legacy_external_id: "legacy-1",
      legacy_imported_at: Time.current,
      legacy_metadata: { "completed" => false },
      needs_structuring: true
    )

    put card_resolution_record_path(@card), params: {
      card_resolution_record: {
        problem_description: "Imported problem",
        reproduction_steps: "Open the imported task",
        expected_behavior: "Expected imported behavior",
        actual_behavior: "Actual imported behavior",
        environment_context: "Imported Asana project"
      }
    }, as: :json

    assert_response :success
    assert_not record.reload.needs_structuring?
  end

  test "update keeps resolved legacy record needing structuring until gate two is complete" do
    record = @card.create_resolution_record!(
      legacy_import: true,
      legacy_source: "asana",
      legacy_external_id: "legacy-2",
      legacy_imported_at: Time.current,
      legacy_metadata: { "completed" => true },
      needs_structuring: true
    )

    put card_resolution_record_path(@card), params: {
      card_resolution_record: {
        problem_description: "Imported problem",
        reproduction_steps: "Open the imported task",
        expected_behavior: "Expected imported behavior",
        actual_behavior: "Actual imported behavior",
        environment_context: "Imported Asana project"
      }
    }, as: :json

    assert_response :success
    assert record.reload.needs_structuring?

    put card_resolution_record_path(@card), params: {
      card_resolution_record: {
        root_cause: "Legacy root cause",
        fix_summary: "Legacy fix summary",
        verification_steps: "Legacy verification"
      }
    }, as: :json

    assert_response :success
    assert_not record.reload.needs_structuring?
  end

  test "update cannot modify inaccessible account card" do
    other_account_card = create_other_account_card

    assert_no_difference -> { Card::ResolutionRecord.count } do
      put card_resolution_record_path(other_account_card), params: {
        card_resolution_record: {
          problem_description: "Should not be saved"
        }
      }, as: :json
    end

    assert_response :not_found
  end

  private
    def create_other_account_card
      Current.with(account: accounts(:initech), session: sessions(:mike)) do
        boards(:miltons_wish_list).cards.create!(
          account: accounts(:initech),
          creator: users(:mike),
          status: :published,
          number: 999,
          title: "Other account card"
        )
      end
    end
end
