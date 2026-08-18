# frozen_string_literal: true

namespace :kiosk_sessions do
  desc "Close kiosk usage sessions left open for more than 12 hours"
  task close_stale: :environment do
    closed = KioskSession.close_stale!
    puts "Closed #{closed} stale kiosk session#{'s' unless closed == 1}."
  end
end
