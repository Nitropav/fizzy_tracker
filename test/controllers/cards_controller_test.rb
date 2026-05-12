require "test_helper"

class CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    get cards_path
    assert_response :success
  end

  test "filtered index" do
    get cards_path(filters(:jz_assignments).as_params.merge(term: "haggis"))
    assert_response :success
  end

  test "create a new draft" do
    assert_difference -> { Card.count }, 1 do
      post board_cards_path(boards(:writebook))
    end

    card = Card.last
    assert_redirected_to card_draft_path(card)

    assert card.drafted?
  end

  test "create resumes existing draft if it exists" do
    draft = boards(:writebook).cards.create!(creator: users(:kevin), status: :drafted)

    assert_no_difference -> { Card.count } do
      post board_cards_path(boards(:writebook))
      assert_redirected_to card_draft_path(draft)
    end
  end

  test "show redirects to draft when card is drafted" do
    card = boards(:writebook).cards.create!(creator: users(:kevin), status: :drafted)

    get card_path(card)
    assert_redirected_to card_draft_path(card)
  end

  test "show renders assign-to-me hotkey using self assignment path" do
    card = cards(:logo)

    get card_path(card)
    assert_response :success

    assert_select "form[action=?] button[hidden]", card_self_assignment_path(card), text: "Assign to me"
    assert_no_match "Moves to", response.body
    assert_no_match "Not Now", response.body
  end

  test "show renders inline code in title" do
    card = cards(:logo)
    card.update_column :title, "Fix the `bug` in production"

    get card_path(card)
    assert_select ".card__title-link" do |element|
      assert_equal "Fix the <code>bug</code> in production", element.inner_html
    end
  end

  test "show renders gate one guidance when card needs reporter info" do
    card = cards(:logo)
    card.create_resolution_record!(
      problem_description: "Logo is unreadable"
    )

    get card_path(card)

    assert_response :success
    assert_match "Needs reporter information", response.body
    assert_match "List the exact steps needed to reproduce it", response.body
    assert_select "form[action=?]", card_gate_one_answer_path(card)
    assert_select "input[name='gate_one_answer[field]'][value='reproduction_steps']"
    assert_match "All missing Gate 1 items", response.body
  end

  test "show renders issue structuring suggestion controls" do
    card = cards(:logo)
    ai_run = Ai::IssueStructuringService.new(card, user: users(:kevin)).suggest

    get card_path(card)

    assert_response :success
    assert_select "form[action=?]", card_structuring_suggestion_path(card)
    assert_match "Suggest structure", response.body
    assert_match "Latest issue structuring suggestion", response.body
    assert_match "Generated deterministic Gate 1 and classification suggestions", response.body
    assert_match "Apply suggestion", response.body
    assert_match ERB::Util.html_escape(ai_run.output.dig("suggested_fields", "structured_summary")), response.body
  end

  test "show auto-refreshes pending AI runs" do
    card = cards(:logo)
    ai_run = AiRun.create!(
      account: card.account,
      card: card,
      user: users(:kevin),
      run_type: "card_quality_review",
      status: :pending,
      input_context: {}
    )
    anchor = ActionView::RecordIdentifier.dom_id(card, :resolution_record)

    get card_path(card)

    assert_response :success
    assert_match "Training quality review is queued.", response.body
    assert_match "This card will update automatically", response.body
    assert_select "[data-controller=?][data-auto-refresh-key-value=?][data-auto-refresh-anchor-value=?]",
      "auto-refresh", ai_run.id, anchor
  end

  test "show renders duplicate suggestion controls" do
    card = cards(:logo)
    Ai::DuplicateIssueSuggestionService.new(card, user: users(:kevin)).suggest

    get card_path(card)

    assert_response :success
    assert_select "form[action=?]", card_duplicate_suggestion_path(card)
    assert_match "Duplicate check", response.body
    assert_match "Find similar issues", response.body
  end

  test "show renders legacy import structuring panel" do
    card = cards(:logo)
    card.create_resolution_record!(
      legacy_import: true,
      legacy_source: "asana",
      legacy_external_id: "1200",
      legacy_imported_at: Time.current,
      legacy_metadata: {
        "completed" => false,
        "permalink_url" => "https://app.asana.com/0/1/1200",
        "created_by" => { "name" => "Reporter User" },
        "assignee" => { "name" => "Developer User" },
        "stories" => [
          {
            "text" => "Reporter added screenshot context",
            "type" => "comment",
            "resource_subtype" => "comment_added"
          }
        ],
        "attachments" => [
          {
            "name" => "image.png",
            "view_url" => "https://asanausercontent.example/image.png",
            "permanent_url" => "https://app.asana.com/app/asana/-/get_asset?asset_id=asset-1"
          }
        ]
      },
      gate_one_legacy: true,
      needs_structuring: true
    )

    get card_path(card)

    assert_response :success
    assert_match "Legacy import", response.body
    assert_match "Needs structuring", response.body
    assert_match "Asana source context", response.body
    assert_match "Reporter User", response.body
    assert_match "Developer User", response.body
    assert_match "Reporter added screenshot context", response.body
    assert_select "a[href=?]", "https://app.asana.com/0/1/1200", text: "Open original task"
    assert_select "img[src=?][alt=?]", "https://asanausercontent.example/image.png", "image.png"
    assert_select "a[href=?]", "https://app.asana.com/app/asana/-/get_asset?asset_id=asset-1", text: "Open original"
  end

  test "show renders linked code evidence" do
    card = cards(:logo)
    card.code_links.create!(
      provider: "github",
      external_type: "pull_request",
      external_id: "123",
      repository: "cactus/fizzy",
      title: "Fix issue workflow",
      url: "https://github.com/cactus/fizzy/pull/123",
      metadata: {}
    )

    get card_path(card)

    assert_response :success
    assert_match "Code evidence", response.body
    assert_match "Fix issue workflow", response.body
    assert_select "a[href=?]", "https://github.com/cactus/fizzy/pull/123", text: "Open"
  end

  test "show hides developer-only issue data from reporters" do
    users(:david).update!(cactus_role: :reporter)
    logout_and_sign_in_as :david

    card = cards(:logo)
    card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small",
      environment_context: "Cactus card page",
      root_cause: "Image sizing used the wrong max width",
      fix_summary: "Adjusted the card image layout",
      verification_steps: "Opened the card and confirmed the logo is readable"
    )
    card.code_links.create!(
      provider: "github",
      external_type: "commit",
      external_id: "abc123",
      repository: "cactus/fizzy",
      title: "Fix issue workflow",
      url: "https://github.com/cactus/fizzy/commit/abc123",
      metadata: {}
    )

    get card_path(card)

    assert_response :success
    assert_match "Reporter-side details", response.body
    assert_match "Problem description", response.body
    assert_no_match "Gate 2 - Developer side", response.body
    assert_no_match "Root cause", response.body
    assert_no_match "Code evidence", response.body
    assert_no_match "Review quality", response.body
  end

  test "show renders mark resolved action when cactus workflow needs review" do
    card = cards(:logo)
    card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small",
      environment_context: "Fizzy card page",
      root_cause: "Image sizing used the wrong max width",
      fix_summary: "Adjusted the card image layout",
      verification_steps: "Opened the card and confirmed the logo is readable"
    )

    get card_path(card)

    assert_response :success
    assert_select "form[action=?]", card_resolution_path(card)
    assert_match "Mark resolved", response.body
  end

  test "show replaces generic done action for cactus workflow cards" do
    card = cards(:logo)
    card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small",
      environment_context: "Fizzy card page",
      root_cause: "Image sizing used the wrong max width",
      fix_summary: "Adjusted the card image layout",
      verification_steps: "Opened the card and confirmed the logo is readable"
    )

    get card_path(card)

    assert_response :success
    assert_no_match "Mark as Done", response.body
    assert_select "a[href=?][data-turbo-frame=?]", edit_card_resolution_record_path(card), "_top", text: "Use Cactus resolution"
  end

  test "show links pending training example after resolution" do
    card = cards(:logo)
    card.create_resolution_record!(
      problem_description: "Logo is unreadable",
      reproduction_steps: "Open the card",
      expected_behavior: "Logo should be readable",
      actual_behavior: "Logo is too small",
      environment_context: "Fizzy card page",
      root_cause: "Image sizing used the wrong max width",
      fix_summary: "Adjusted the card image layout",
      verification_steps: "Opened the card and confirmed the logo is readable"
    )
    card.code_links.create!(
      provider: "github",
      external_type: "commit",
      external_id: "abc123",
      repository: "cactus/fizzy",
      title: "Fix issue workflow",
      url: "https://github.com/cactus/fizzy/commit/abc123",
      metadata: {}
    )
    training_example = card.resolve(user: users(:kevin))

    get card_path(card)

    assert_response :success
    assert_select "a[href=?]", training_example_path(training_example), text: "Review example"
  end

  test "edit" do
    get edit_card_path(cards(:logo))
    assert_response :success
  end

  test "edit card with invalid attachments in description" do
    card = cards(:logo)
    card.update! description: <<~HTML
      <action-text-attachment sgid="gid://fizzy/Card/nonexistent" content-type="application/octet-stream"></action-text-attachment>
    HTML

    get edit_card_path(card)
    assert_response :success
  end

  test "update" do
    patch card_path(cards(:logo)), as: :turbo_stream, params: {
      card: {
        title: "Logo needs to change",
        image: fixture_file_upload("moon.jpg", "image/jpeg"),
        description: "Something more in-depth" } }
    assert_response :success

    card = cards(:logo).reload
    assert_equal "Logo needs to change", card.title
    assert_equal "moon.jpg", card.image.filename.to_s
    assert_equal "Something more in-depth", card.description.to_plain_text.strip
  end

  test "update draft card does not render reactions" do
    draft = boards(:writebook).cards.create!(creator: users(:kevin), status: :drafted)

    patch card_path(draft), as: :turbo_stream, params: {
      card: { image: fixture_file_upload("moon.jpg", "image/jpeg") }
    }
    assert_response :success

    assert_no_match "reactions", response.body, "Draft card should not show reactions/boost button"
  end

  test "users can only see cards in boards they have access to" do
    get card_path(cards(:logo))
    assert_response :success

    boards(:writebook).update! all_access: false
    boards(:writebook).accesses.revoke_from users(:kevin)

    get card_path(cards(:logo))
    assert_response :not_found
  end

  test "admins can see delete button on any card" do
    get card_path(cards(:logo))
    assert_response :success

    assert_match "Delete this card", response.body
  end

  test "card creators can see delete button on their own cards" do
    logout_and_sign_in_as :david

    get card_path(cards(:logo))
    assert_response :success

    assert_match "Delete this card", response.body
  end

  test "non-admins cannot see delete button on cards they did not create" do
    logout_and_sign_in_as :jz

    get card_path(cards(:logo))
    assert_response :success

    assert_no_match "Delete this card", response.body
  end

  test "non-admins cannot delete cards they did not create" do
    logout_and_sign_in_as :jz

    assert_no_difference -> { Card.count } do
      delete card_path(cards(:logo))
    end

    assert_response :forbidden
  end

  test "card creators can delete their own cards" do
    logout_and_sign_in_as :david

    assert_difference -> { Card.count }, -1 do
      delete card_path(cards(:logo))
    end

    assert_redirected_to boards(:writebook)
  end

  test "admins can delete any card" do
    assert_difference -> { Card.count }, -1 do
      delete card_path(cards(:logo))
    end

    assert_redirected_to boards(:writebook)
  end

  test "show card with comment containing malformed remote image attachment" do
    card = cards(:logo)
    card.comments.create! \
      creator: users(:kevin),
      body: '<action-text-attachment url="image.png" content-type="image/*" presentation="gallery"></action-text-attachment>'

    get card_path(card)
    assert_response :success
  end

  test "show as JSON" do
    card = cards(:logo)
    card.steps.create!(content: "First step")
    card.steps.create!(content: "Second step", completed: true)

    get card_path(card), as: :json
    assert_response :success

    assert_equal card.title, @response.parsed_body["title"]
    assert_equal card.closed?, @response.parsed_body["closed"]
    assert_equal card.postponed?, @response.parsed_body["postponed"]
    assert_equal 2, @response.parsed_body["steps"].size
    assert_equal card_comments_url(card), @response.parsed_body["comments_url"]
    assert_equal card_reactions_url(card), @response.parsed_body["reactions_url"]
  end

  test "create as JSON" do
    assert_difference -> { Card.count }, +1 do
      post board_cards_path(boards(:writebook)),
        params: { card: { title: "My new card", description: "Big if true" } },
        as: :json
      assert_response :created
    end

    card = Card.last
    assert_equal card_path(card, format: :json), @response.headers["Location"]
    assert_equal "My new card", @response.parsed_body["title"]

    assert_equal "My new card", card.title
    assert_equal "Big if true", card.description.to_plain_text
    assert_includes card.resolution_record.problem_description, "My new card"
    assert_includes card.resolution_record.problem_description, "Big if true"
  end

  test "create as JSON with custom created_at" do
    custom_time = Time.utc(2024, 1, 15, 10, 30, 0)

    assert_difference -> { Card.count }, +1 do
      post board_cards_path(boards(:writebook)),
        params: { card: { title: "Backdated card", created_at: custom_time } },
        as: :json
      assert_response :created
    end

    assert_equal custom_time, Card.last.created_at
  end

  test "create as JSON with custom last_active_at" do
    created_time = Time.utc(2024, 1, 15, 10, 30, 0)
    last_active_time = Time.utc(2024, 6, 1, 12, 0, 0)

    assert_difference -> { Card.count }, +1 do
      post board_cards_path(boards(:writebook)),
        params: { card: { title: "Card with activity", created_at: created_time, last_active_at: last_active_time } },
        as: :json
      assert_response :created
    end

    card = Card.last
    assert_equal created_time, card.created_at
    assert_equal last_active_time, card.last_active_at
  end

  test "create as JSON defaults last_active_at to created_at when not provided" do
    created_time = Time.utc(2024, 1, 15, 10, 30, 0)

    assert_difference -> { Card.count }, +1 do
      post board_cards_path(boards(:writebook)),
        params: { card: { title: "Backdated card without last_active_at", created_at: created_time } },
        as: :json
      assert_response :created
    end

    card = Card.last
    assert_equal created_time, card.created_at
    assert_equal created_time, card.last_active_at
  end

  test "update as JSON with custom last_active_at" do
    card = cards(:logo)
    custom_time = Time.utc(2024, 3, 15, 14, 0, 0)

    put card_path(card, format: :json), params: { card: { last_active_at: custom_time } }

    assert_response :success
    assert_equal custom_time, card.reload.last_active_at
  end

  test "update as JSON can restore last_active_at after comments overwrite it" do
    created_time = Time.utc(2024, 1, 15, 10, 30, 0)
    last_active_time = Time.utc(2024, 6, 1, 12, 0, 0)

    # Create a card with custom timestamps (simulating import)
    post board_cards_path(boards(:writebook)),
      params: { card: { title: "Imported card", created_at: created_time, last_active_at: last_active_time } },
      as: :json
    assert_response :created

    card = Card.last

    # Adding a comment overwrites last_active_at (this is expected)
    card.comments.create!(creator: users(:kevin), body: "Imported comment")
    assert_not_equal last_active_time, card.reload.last_active_at

    # After import, restore the correct last_active_at
    put card_path(card, format: :json), params: { card: { last_active_at: last_active_time } }
    assert_response :success

    assert_equal last_active_time, card.reload.last_active_at
  end

  test "update as JSON" do
    card = cards(:logo)

    put card_path(card, format: :json), params: { card: { title: "Update test" } }
    assert_response :success

    assert_equal "Update test", card.reload.title
  end

  test "delete as JSON" do
    card = cards(:logo)

    delete card_path(card, format: :json)
    assert_response :no_content

    assert_not Card.exists?(card.id)
  end
end
