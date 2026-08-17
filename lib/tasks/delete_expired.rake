# lib/tasks/delete_expired.rake

namespace :slides do
  desc "Delete slides that have been expired for one week or more"
  task delete_expired: :environment do
    cutoff = 1.week.ago.to_date

    expired = Slide
      .where("end_date IS NOT NULL AND end_date <= ?", cutoff)

    total = expired.count
    if total.zero?
      puts "✅ No slides expired on or before #{cutoff}."
      next
    end

    deleted = 0
    expired.find_each do |slide|
      puts "🗑️  Deleting expired Slide ##{slide.id} “#{slide.title}” (expired on #{slide.end_date})"
      slide.image.purge if slide.image.attached?
      slide.destroy!
      deleted += 1
    end

    puts "✅ Deleted #{deleted} expired slide#{'s' unless deleted == 1} (expired on or before #{cutoff})."
  end
end
