class CreateKioskHeartbeats < ActiveRecord::Migration[7.1]
  def change
    create_table :kiosk_heartbeats do |t|
      t.string   :kiosk_id, null: false
      t.datetime :last_seen_at, null: false
      t.bigint   :uptime_seconds
      t.string   :kiosk_service
      t.integer  :chromium_pids
      t.jsonb    :raw_payload, null: false, default: {}

      t.timestamps
    end

    add_index :kiosk_heartbeats, :kiosk_id, unique: true
    add_index :kiosk_heartbeats, :last_seen_at
  end
end
