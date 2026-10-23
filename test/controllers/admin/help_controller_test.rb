require "test_helper"

class Admin::HelpControllerTest < ActionController::TestCase
  tests Admin::HelpController

  test "anonymous visitors must log in" do
    get :show
    assert_redirected_to login_path
  end

  test "staff can read help without slide management permission" do
    @request.session[:user_id] = users(:two).id
    get :show
    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_select "title", text: "Help · Kiosk Screensaver"
    assert_select "h1", text: "Help"
    assert_select "h2", text: "How to add a slide to one or more kiosks"
    assert_select "a[href=?]", admin_help_path, text: "Help"
    assert_select "a[href=?]", new_admin_slide_path, count: 0
    assert_select ".admin-help figure img", count: 4
  end
end
