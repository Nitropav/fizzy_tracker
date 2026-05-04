require "test_helper"

class Boards::ColumnsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "show" do
    get board_column_path(boards(:writebook), columns(:writebook_in_progress))
    assert_response :success
  end

  test "new" do
    get new_board_column_path(boards(:writebook))

    assert_response :success
    assert_select "h1", text: "New project column"
    assert_select "form[action=?][method=?]", board_columns_path(boards(:writebook)), "post"
    assert_select "input[name='column[name]']"
  end

  test "developers cannot create project columns" do
    logout_and_sign_in_as :david

    get new_board_column_path(boards(:writebook))
    assert_response :forbidden

    assert_no_difference -> { boards(:writebook).columns.count } do
      post board_columns_path(boards(:writebook)), params: { column: { name: "Developer Column" } }
    end
    assert_response :forbidden
  end

  test "create" do
    assert_difference -> { boards(:writebook).columns.count }, +1 do
      post board_columns_path(boards(:writebook)), params: { column: { name: "New Column" } }, as: :turbo_stream
      assert_response :success
    end

    assert_equal "New Column", boards(:writebook).columns.last.name
  end

  test "create as HTML redirects back to board" do
    assert_difference -> { boards(:writebook).columns.count }, +1 do
      post board_columns_path(boards(:writebook)), params: { column: { name: "New Column" } }
    end

    assert_redirected_to board_path(boards(:writebook))
    assert_equal "New Column", boards(:writebook).columns.last.name
  end

  test "create refreshes adjacent columns" do
    board = boards(:writebook)

    post board_columns_path(board), params: { column: { name: "New Column" } }, as: :turbo_stream

    new_column = board.columns.find_by!(name: "New Column")
    new_column.adjacent_columns.each do |adjacent_column|
      assert_turbo_stream action: :replace, target: dom_id(adjacent_column)
    end
  end

  test "update" do
    column = columns(:writebook_in_progress)

    assert_changes -> { column.reload.name }, from: "In progress", to: "Updated Name" do
      put board_column_path(boards(:writebook), column), params: { column: { name: "Updated Name" } }, as: :turbo_stream
      assert_response :success
    end
  end

  test "developers cannot update or destroy project columns" do
    logout_and_sign_in_as :david

    column = columns(:writebook_in_progress)
    original_name = column.name

    put board_column_path(column.board, column), params: { column: { name: "Developer Rename" } }, as: :turbo_stream
    assert_response :forbidden
    assert_equal original_name, column.reload.name

    assert_no_difference -> { column.board.columns.count } do
      delete board_column_path(column.board, column), as: :turbo_stream
    end
    assert_response :forbidden
  end

  test "destroy" do
    column = columns(:writebook_in_progress)
    adjacent_columns = column.adjacent_columns.to_a

    delete board_column_path(column.board, column), as: :turbo_stream

    assert_redirected_to board_path(column.board)
  end

  test "index as JSON" do
    board = boards(:writebook)

    get board_columns_path(board), as: :json

    assert_response :success
    assert_equal board.columns.count, @response.parsed_body.count
  end

  test "show as JSON" do
    column = columns(:writebook_in_progress)

    get board_column_path(column.board, column), as: :json

    assert_response :success
    assert_equal column.id, @response.parsed_body["id"]
  end

  test "create as JSON" do
    board = boards(:writebook)

    assert_difference -> { board.columns.count }, +1 do
      post board_columns_path(board), params: { column: { name: "New Column" } }, as: :json
    end

    assert_response :created
    assert_equal board_column_path(board, Column.last, format: :json), @response.headers["Location"]
    assert_equal "New Column", @response.parsed_body["name"]
  end

  test "update as JSON" do
    column = columns(:writebook_in_progress)

    put board_column_path(column.board, column), params: { column: { name: "Updated Name" } }, as: :json

    assert_response :no_content
    assert_equal "Updated Name", column.reload.name
  end

  test "destroy as JSON" do
    column = columns(:writebook_on_hold)

    assert_difference -> { column.board.columns.count }, -1 do
      delete board_column_path(column.board, column), as: :json
    end

    assert_response :no_content
  end
end
