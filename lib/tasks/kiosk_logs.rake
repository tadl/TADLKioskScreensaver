# frozen_string_literal: true

namespace :kiosk_logs do
  desc "Delete kiosk logs older than the retention window (default: 180 days)"
  task purge_old: :environment do
    retention_days = ENV.fetch("RETENTION_DAYS", 180).to_i
    cutoff = retention_days.days.ago

    scope = KioskLog.where("occurred_at < ?", cutoff)
    total = scope.count

    if total.zero?
      puts "✅ No kiosk logs older than #{cutoff}."
      next
    end

    deleted = 0

    scope.in_batches(of: 1_000) do |relation|
      deleted += relation.delete_all
    end

    puts "✅ Deleted #{deleted} kiosk log#{'s' unless deleted == 1} older than #{cutoff}."
  end
end
