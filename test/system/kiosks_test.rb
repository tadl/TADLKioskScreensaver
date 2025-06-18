require "application_system_test_case"

class KiosksTest < ApplicationSystemTestCase
  setup do
    @kiosk = kiosks(:one)
  end

  test "visiting the index" do
    visit kiosks_url
    assert_selector "h1", text: "Kiosks"
  end

  test "should create kiosk" do
    visit kiosks_url
    click_on "New kiosk"

    fill_in "Catalog url", with: @kiosk.catalog_url
    fill_in "Name", with: @kiosk.name
    fill_in "Slug", with: @kiosk.slug
    click_on "Create Kiosk"

    assert_text "Kiosk was successfully created"
    click_on "Back"
  end

  test "should update Kiosk" do
    visit kiosk_url(@kiosk)
    click_on "Edit this kiosk", match: :first

    fill_in "Catalog url", with: @kiosk.catalog_url
    fill_in "Name", with: @kiosk.name
    fill_in "Slug", with: @kiosk.slug
    click_on "Update Kiosk"

    assert_text "Kiosk was successfully updated"
    click_on "Back"
  end

  test "should destroy Kiosk" do
    visit kiosk_url(@kiosk)
    accept_confirm { click_on "Destroy this kiosk", match: :first }

    assert_text "Kiosk was successfully destroyed"
  end
end
