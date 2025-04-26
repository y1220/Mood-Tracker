require "test_helper"

class SubtasksControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get subtasks_create_url
    assert_response :success
  end

  test "should get update" do
    get subtasks_update_url
    assert_response :success
  end

  test "should get destroy" do
    get subtasks_destroy_url
    assert_response :success
  end

  test "should get select_subtasks" do
    get subtasks_select_subtasks_url
    assert_response :success
  end
end
