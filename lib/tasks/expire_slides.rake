# lib/tasks/expire_slides.rake

namespace :slides do
  desc "Remove expired slides from all kiosk assignments"
  task expire: :environment do
    today = Date.current

    Slide
      .where("end_date IS NOT NULL AND end_date < ?", today)
      .find_each do |slide|
        next if slide.kiosk_ids.empty?

        slide.kiosks.clear
        puts "► Cleared Slide ##{slide.id} (‘#{slide.title}’) from kiosks"
      end

    puts "✅ Done removing expired slides from kiosks."
  end
end
