class AddChromiumHealthToKioskHeartbeats < ActiveRecord::Migration[7.1]
  def change
    add_column :kiosk_heartbeats, :chromium_devtools_ok, :boolean
    add_column :kiosk_heartbeats, :chromium_devtools_http, :string
    add_column :kiosk_heartbeats, :chromium_devtools_ms, :integer
  end
end
