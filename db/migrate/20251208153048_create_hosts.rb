# db/migrate/20251208000000_create_hosts.rb
class CreateHosts < ActiveRecord::Migration[7.1]
  def change
    create_table :hosts do |t|
      t.string  :name, null: false            # e.g., "nucpac02"
      t.string  :location                     # free-form "Peninsula Info Desk", etc.
      t.text    :notes                        # deprovisioning notes, quirks, etc.
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :hosts, :name, unique: true
  end
end
