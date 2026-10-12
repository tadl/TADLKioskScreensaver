require "test_helper"

class Admin::KioskHostsControllerTest < ActionController::TestCase
  tests Admin::KioskHostsController

  setup do
    @user = User.create!(email: "host-viewer@example.com", name: "Host Viewer")
    permission = Permission.find_or_create_by!(name: "manage_slides")
    user_permission = UserPermission.create!(user: @user, permission: permission)
    user_permission.kiosks << kiosks(:one)
    @request.session[:user_id] = @user.id
  end

  test "allows host details for an accessible kiosk" do
    KioskStatus.mark!(kiosk: kiosks(:one), host: "allowed-host", state: :screensaver)

    get :show, params: { host: "allowed-host", format: :json }

    assert_response :success
    assert_equal "allowed-host", response.parsed_body["host"]
  end

  test "denies host details for an inaccessible kiosk" do
    KioskStatus.mark!(kiosk: kiosks(:two), host: "hidden-host", state: :screensaver)

    get :show, params: { host: "hidden-host", format: :json }

    assert_response :forbidden
  end
end

class Admin::KioskHostRoutesTest < ActionDispatch::IntegrationTest
  test "routes dotted hostnames to the authenticated host-details endpoint" do
    path = "/admin/kiosk_hosts/demo.example.com.json"
    route = Rails.application.routes.recognize_path(path)

    assert_equal "admin/kiosk_hosts", route[:controller]
    assert_equal "demo.example.com", route[:host]
    assert_equal "json", route[:format].to_s

    get path
    assert_response :unauthorized

    route = Rails.application.routes.recognize_path("/admin/kiosk_hosts/demo.example.com")
    assert_equal "demo.example.com", route[:host]
  end
end
