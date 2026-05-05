require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  STRONG_PASSWORD = "correct horse battery staple"

  test "show" do
    sign_in_as :kevin

    get user_path(users(:david))
    assert_in_body users(:david).name
  end

  test "create user login as admin" do
    sign_in_as :kevin
    email_address = "new-user-#{SecureRandom.hex(6)}@example.com"

    assert_difference -> { Identity.count }, +1 do
      assert_difference -> { users(:kevin).account.users.active.count }, +1 do
        post users_path, params: {
          user: {
            name: "New User",
            email_address: email_address,
            password: STRONG_PASSWORD,
            password_confirmation: STRONG_PASSWORD,
            role: "admin",
            cactus_role: "developer"
          }
        }
      end
    end

    assert_redirected_to account_settings_path

    identity = Identity.find_by!(email_address: email_address)
    user = users(:kevin).account.users.find_by!(identity: identity)
    assert identity.authenticate(STRONG_PASSWORD)
    assert_equal "New User", user.name
    assert user.admin?
    assert user.developer?
    assert user.verified?
  end

  test "create user rejects weak password" do
    sign_in_as :kevin

    assert_no_difference -> { Identity.count } do
      assert_no_difference -> { users(:kevin).account.users.active.count } do
        post users_path, params: {
          user: {
            name: "Weak User",
            email_address: "weak-user-#{SecureRandom.hex(6)}@example.com",
            password: "short",
            password_confirmation: "short",
            role: "member",
            cactus_role: "reporter"
          }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_match "Password is too short", response.body
  end

  test "create user rejects existing email" do
    sign_in_as :kevin

    assert_no_difference -> { Identity.count } do
      assert_no_difference -> { users(:kevin).account.users.active.count } do
        post users_path, params: {
          user: {
            name: "Existing User",
            email_address: identities(:david).email_address,
            password: STRONG_PASSWORD,
            password_confirmation: STRONG_PASSWORD,
            role: "member",
            cactus_role: "reporter"
          }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_match "Email address is already in use", response.body
  end

  test "non-admins cannot create user logins" do
    sign_in_as :jz

    assert_no_difference -> { Identity.count } do
      post users_path, params: {
        user: {
          name: "Blocked User",
          email_address: "blocked-user-#{SecureRandom.hex(6)}@example.com",
          password: STRONG_PASSWORD,
          password_confirmation: STRONG_PASSWORD,
          role: "member",
          cactus_role: "reporter"
        }
      }
    end

    assert_response :forbidden
  end

  test "update oneself" do
    sign_in_as :kevin

    get edit_user_path(users(:kevin))
    assert_response :ok

    put user_path(users(:kevin)), params: { user: { name: "New Kevin" } }
    assert_redirected_to user_path(users(:kevin))
    assert_equal "New Kevin", users(:kevin).reload.name
  end

  test "update other as admin" do
    sign_in_as :kevin

    get edit_user_path(users(:david))
    assert_response :ok

    put user_path(users(:david)), params: { user: { name: "New David" } }
    assert_redirected_to user_path(users(:david))
    assert_equal "New David", users(:david).reload.name
  end

  test "destroy" do
    sign_in_as :kevin

    assert_difference -> { User.active.count }, -1 do
      delete user_path(users(:david))
    end

    assert_redirected_to account_settings_path
    assert_nil User.active.find_by(id: users(:david).id)
  end

  test "admin cannot deactivate the owner" do
    sign_in_as :kevin

    assert users(:jason).owner?
    assert users(:jason).active

    assert_no_difference -> { User.active.count } do
      delete user_path(users(:jason))
    end

    assert_response :forbidden
    assert users(:jason).reload.active
  end

  test "non-admins cannot perform actions" do
    sign_in_as :jz

    put user_path(users(:david)), params: { user: { role: "admin" } }
    assert_response :forbidden

    delete user_path(users(:david))
    assert_response :forbidden
  end

  test "update with invalid avatar content type shows validation error" do
    sign_in_as :kevin

    svg_file = fixture_file_upload("avatar.svg", "image/svg+xml")

    put user_path(users(:kevin)), params: { user: { avatar: svg_file } }
    assert_response :unprocessable_entity
    assert_select "form[action='#{user_path(users(:kevin))}']"
    assert_select ".txt-negative", text: /must be a JPEG, PNG, GIF, or WebP image/
  end

  test "update with oversized avatar shows validation error" do
    skip "New uploads are dimension-validated after ActiveStorage analysis metadata exists"

    sign_in_as :kevin

    png_file = fixture_file_upload("avatar.png", "image/png")

    ActiveStorage::Analyzer::ImageAnalyzer::Vips.any_instance.stubs(:metadata).returns({ width: 5000, height: 100 })

    put user_path(users(:kevin)), params: { user: { avatar: png_file } }
    assert_response :unprocessable_entity
    assert_select ".txt-negative", text: /width must be less than 4096px/
  end

  test "update with valid avatar" do
    sign_in_as :kevin

    png_file = fixture_file_upload("avatar.png", "image/png")

    put user_path(users(:kevin)), params: { user: { avatar: png_file } }
    assert_redirected_to user_path(users(:kevin))
    assert users(:kevin).reload.avatar.attached?
    assert_equal "image/png", users(:kevin).avatar.content_type
  end

  test "index as JSON" do
    sign_in_as :kevin

    get users_path, as: :json
    assert_response :success
    assert_equal users(:kevin).account.users.active.count, @response.parsed_body.count
  end

  test "show as JSON" do
    sign_in_as :kevin

    get user_path(users(:david)), as: :json
    assert_response :success
    assert_equal users(:david).name, @response.parsed_body["name"]
  end

  test "update as JSON" do
    sign_in_as :kevin

    put user_path(users(:david)), params: { user: { name: "New David" } }, as: :json

    assert_response :no_content
    assert_equal "New David", users(:david).reload.name
  end

  test "update as JSON with invalid avatar returns errors" do
    sign_in_as :kevin

    svg_file = fixture_file_upload("avatar.svg", "image/svg+xml")

    put user_path(users(:kevin), format: :json), params: { user: { avatar: svg_file } }

    assert_response :unprocessable_entity
    assert @response.parsed_body["avatar"].present?
  end

  test "destroy as JSON" do
    sign_in_as :kevin

    assert_difference -> { User.active.count }, -1 do
      delete user_path(users(:david)), as: :json
    end

    assert_response :no_content
  end

  test "bearer token does not authenticate HTML requests" do
    sign_in_as :jason
    sign_out

    bearer = { "HTTP_AUTHORIZATION" => "Bearer #{identity_access_tokens(:jasons_api_token).token}" }
    get user_path(users(:jason)), env: bearer

    assert_response :unauthorized
  end

  test "bearer token authenticates JSON requests" do
    sign_in_as :jason
    sign_out

    bearer = { "HTTP_AUTHORIZATION" => "Bearer #{identity_access_tokens(:jasons_api_token).token}" }
    get user_path(users(:jason)), env: bearer, as: :json

    assert_response :success
  end

  test "index avoids N+1 queries on identity" do
    sign_in_as :kevin

    assert_queries_match(/FROM [`"]identities[`"].* IN \(/, count: 1) do
      get users_path, as: :json
      assert_response :success
    end

    json = @response.parsed_body
    assert json.first["email_address"].present?
  end
end
