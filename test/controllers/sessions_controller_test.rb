require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "OAuth failures return to login" do
    get "/auth/failure"

    assert_redirected_to login_path
    assert_equal "Authentication failed, please try again.", flash[:alert]
  end

  test "callbacks without authentication data return to login" do
    get "/auth/google_oauth2/callback"
    follow_redirect!

    assert_redirected_to login_path
    assert_equal "Authentication failed, please try again.", flash[:alert]
  end
end
