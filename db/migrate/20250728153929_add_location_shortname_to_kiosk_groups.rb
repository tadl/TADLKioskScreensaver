class AddLocationShortnameToKioskGroups < ActiveRecord::Migration[7.1]
  def change
    add_column :kiosk_groups, :location_shortname, :string
    add_index :kiosk_groups, :location_shortname
  end
end
