require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "OAuth failures return to login" do
    get "/auth/failure"

    assert_redirected_to login_path
    assert_equal "Authentication failed, please try again.", flash[:alert]
  end

end

class SessionsControllerCallbackTest < ActionController::TestCase
  tests SessionsController

  test "callbacks without authentication data return to login" do
    @request.env.delete("omniauth.auth")
    get :create, params: { provider: "google_oauth2" }

    assert_redirected_to login_path
    assert_equal "Authentication failed, please try again.", flash[:alert]
  end
end
