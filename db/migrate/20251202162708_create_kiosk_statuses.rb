class CreateKioskStatuses < ActiveRecord::Migration[7.1]
  def change
    create_table :kiosk_statuses do |t|
      t.references :kiosk, null: false, foreign_key: true
      t.string     :host, null: false
      t.integer    :state, null: false, default: 0 # 0=screensaver, 1=opac
      t.datetime   :state_changed_at, null: false

      t.timestamps
    end

    add_index :kiosk_statuses, [:kiosk_id, :host], unique: true
  end
end
