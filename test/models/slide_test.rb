require "test_helper"

class SlideTest < ActiveSupport::TestCase
  test "processes an uploaded slide thumbnail without changing the original" do
    Tempfile.create(["slide", ".png"]) do |file|
      MiniMagick.convert do |command|
        command.size "1920x1080"
        command << "xc:navy"
        command << file.path
      end

      blob = ActiveStorage::Blob.create_and_upload!(
        io: file,
        filename: "synthetic-slide.png",
        content_type: "image/png"
      )
      begin
        slide = Slide.create!(title: "Synthetic Slide", image: blob)
        thumbnail = slide.image.variant(resize_to_limit: [150, 150]).processed

        assert_equal [150, 84], MiniMagick::Image.read(thumbnail.download).dimensions
        assert_equal [1920, 1080], MiniMagick::Image.read(blob.download).dimensions
      ensure
        slide&.persisted? ? slide.image.purge : blob.purge
      end
    end
  end

  test "applies default display time and start date" do
    slide = create_slide_with_image!(title: "New Slide")

    assert_equal 10, slide.display_seconds
    assert_equal Date.current, slide.start_date
  end

  test "requires an image" do
    slide = Slide.new(title: "Missing Image")

    assert_not slide.valid?
    assert_includes slide.errors[:image], "must be attached"
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
