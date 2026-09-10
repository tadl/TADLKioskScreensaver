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

  test "a successful staff callback preserves the existing admin account" do
    stub_const(Object, :GOOGLE_DOMAIN, "example.com") do
      @request.env["omniauth.auth"] = OmniAuth::AuthHash.new(
        provider: "google_oauth2",
        uid: "synthetic-admin-id",
        info: { email: "admin@example.com", name: "Admin User" }
      )

      get :create, params: { provider: "google_oauth2" }

      assert_redirected_to "/admin/"
      assert_equal users(:one).id, session[:user_id]
      assert_predicate users(:one).reload, :admin?
    end
  end

  test "a callback from another domain cannot keep an authenticated session" do
    stub_const(Object, :GOOGLE_DOMAIN, "example.com") do
      @request.session[:user_id] = users(:one).id
      @request.env["omniauth.auth"] = OmniAuth::AuthHash.new(
        provider: "google_oauth2",
        uid: "synthetic-outsider-id",
        info: { email: "outsider@example.net", name: "Outside User" }
      )

      assert_no_difference "User.count" do
        get :create, params: { provider: "google_oauth2" }
      end

      assert_redirected_to root_path
      assert_nil session[:user_id]
    end
  end

  test "callbacks without authentication data return to login" do
    @request.env.delete("omniauth.auth")
    get :create, params: { provider: "google_oauth2" }

    assert_redirected_to login_path
    assert_equal "Authentication failed, please try again.", flash[:alert]
  end
end
