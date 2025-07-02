# lib/tasks/invalid_slides.rake
namespace :slides do
  desc "Delete slides with missing or non-1920×1080 images"
  task delete_invalid: :environment do
    # Build a relation of slides that are invalid:
    #  • No attachment, or
    #  • Width ≠ 1920, or
    #  • Height ≠ 1080
    invalid_slides = Slide
      .left_outer_joins(image_attachment: :blob)
      .where("active_storage_attachments.id IS NULL 
              OR (active_storage_blobs.metadata::json->>'width')  <> '1920'
              OR (active_storage_blobs.metadata::json->>'height') <> '1080'")
    
    total = invalid_slides.count
    if total.zero?
      puts "✅ No invalid slides found."
      next
    end

    invalid_slides.find_each do |slide|
      puts "🗑️  Deleting Slide ##{slide.id} “#{slide.title}”"
      slide.destroy
    end

    puts "✅ Deleted #{total} invalid slide#{'s' unless total == 1}."
  end
end
