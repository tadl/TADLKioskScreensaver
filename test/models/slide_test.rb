require "test_helper"

class SlideTest < ActiveSupport::TestCase
  test "applies default display time and start date" do
    slide = Slide.create!(title: "New Slide")

    assert_equal 10, slide.display_seconds
    assert_equal Date.current, slide.start_date
  end

  test "requires end date to be on or after start date" do
    slide = Slide.new(
      title: "Bad Date Range",
      start_date: Date.current,
      end_date: Date.current - 1
    )

    assert_not slide.valid?
    assert_includes slide.errors[:end_date], "must be on or after the start date"
  end
end
