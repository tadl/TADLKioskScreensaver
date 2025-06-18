class CreateKioskGroups < ActiveRecord::Migration[7.0]
  def change
    create_table :kiosk_groups do |t|
      t.string :name, null: false
      t.string :slug, null: false, index: { unique: true }
      t.timestamps
    end
  end
end

