class CreateKioskLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :kiosk_logs do |t|
      t.string   :kiosk_id, null: false
      t.datetime :occurred_at, null: false
      t.string   :level
      t.text     :message
      t.jsonb    :raw_payload, null: false, default: {}

      t.timestamps
    end

    add_index :kiosk_logs, :kiosk_id
    add_index :kiosk_logs, :occurred_at
  end
end
