ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "rake"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def build_slide_with_image(attributes = {})
      Slide.new(attributes).tap do |slide|
        blob = ActiveStorage::Blob.create_and_upload!(
          io: StringIO.new("fake image bytes"),
          filename: "#{attributes.fetch(:title, 'slide').parameterize}.jpg",
          content_type: "image/jpeg",
          metadata: { width: 1920, height: 1080 },
          identify: false
        )
        slide.image.attach(blob)
      end
    end

    def create_slide_with_image!(attributes = {})
      build_slide_with_image(attributes).tap(&:save!)
    end

    def load_rake_task(task_name, file_name)
      Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
      Rake.application.rake_require("tasks/#{file_name}", [Rails.root.join("lib").to_s])
      Rake::Task[task_name].reenable
    end
  end
end
