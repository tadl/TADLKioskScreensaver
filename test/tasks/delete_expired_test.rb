require "test_helper"
require "rake"

class DeleteExpiredTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("slides:delete_expired")
    Rake::Task["slides:delete_expired"].reenable
  end

  test "deletes expired slides and purges their blobs synchronously" do
    slide = create_slide_with_image!(
      title: "Old Campaign",
      start_date: 30.days.ago.to_date,
      end_date: 8.days.ago.to_date
    )
    blob_id = slide.image.blob.id

    capture_io { Rake::Task["slides:delete_expired"].invoke }

    assert_not Slide.exists?(slide.id)
    assert_not ActiveStorage::Blob.exists?(blob_id)
  end
end
