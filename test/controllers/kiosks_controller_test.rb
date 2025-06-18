require "test_helper"

class KiosksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @kiosk = kiosks(:one)
  end

  test "should get index" do
    get kiosks_url
    assert_response :success
  end

  test "should get new" do
    get new_kiosk_url
    assert_response :success
  end

  test "should create kiosk" do
    assert_difference("Kiosk.count") do
      post kiosks_url, params: { kiosk: { catalog_url: @kiosk.catalog_url, name: @kiosk.name, slug: @kiosk.slug } }
    end

    assert_redirected_to kiosk_url(Kiosk.last)
  end

  test "should show kiosk" do
    get kiosk_url(@kiosk)
    assert_response :success
  end

  test "should get edit" do
    get edit_kiosk_url(@kiosk)
    assert_response :success
  end

  test "should update kiosk" do
    patch kiosk_url(@kiosk), params: { kiosk: { catalog_url: @kiosk.catalog_url, name: @kiosk.name, slug: @kiosk.slug } }
    assert_redirected_to kiosk_url(@kiosk)
  end

  test "should destroy kiosk" do
    assert_difference("Kiosk.count", -1) do
      delete kiosk_url(@kiosk)
    end

    assert_redirected_to kiosks_url
  end
end
