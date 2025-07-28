class CreateKioskSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :kiosk_sessions do |t|
      t.string :kiosk_code, null: false
      t.string :host # Hostname, optional
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.integer :slide_fetch_count, default: 0
      t.timestamps
    end

    add_index :kiosk_sessions, [:kiosk_code, :host, :started_at]
  end
end
