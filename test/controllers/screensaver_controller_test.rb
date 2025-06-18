require "test_helper"

class ScreensaverControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get screensaver_index_url
    assert_response :success
  end
end
