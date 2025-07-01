class AddLocationToKiosks < ActiveRecord::Migration[7.1]
  def change
    add_column :kiosks, :location, :string
  end
end
