require "application_system_test_case"

class SlidesTest < ApplicationSystemTestCase
  setup do
    @slide = slides(:one)
  end

  test "visiting the index" do
    visit slides_url
    assert_selector "h1", text: "Slides"
  end

  test "should create slide" do
    visit slides_url
    click_on "New slide"

    fill_in "Display seconds", with: @slide.display_seconds
    fill_in "End date", with: @slide.end_date
    fill_in "Link", with: @slide.link
    fill_in "Start date", with: @slide.start_date
    fill_in "Title", with: @slide.title
    click_on "Create Slide"

    assert_text "Slide was successfully created"
    click_on "Back"
  end

  test "should update Slide" do
    visit slide_url(@slide)
    click_on "Edit this slide", match: :first

    fill_in "Display seconds", with: @slide.display_seconds
    fill_in "End date", with: @slide.end_date
    fill_in "Link", with: @slide.link
    fill_in "Start date", with: @slide.start_date
    fill_in "Title", with: @slide.title
    click_on "Update Slide"

    assert_text "Slide was successfully updated"
    click_on "Back"
  end

  test "should destroy Slide" do
    visit slide_url(@slide)
    accept_confirm { click_on "Destroy this slide", match: :first }

    assert_text "Slide was successfully destroyed"
  end
end
