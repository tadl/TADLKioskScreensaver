class AddKioskGroupToKiosks < ActiveRecord::Migration[7.0]
  def change
    add_reference :kiosks, :kiosk_group, foreign_key: true, index: true
  end
end

