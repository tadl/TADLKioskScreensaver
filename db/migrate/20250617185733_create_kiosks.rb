class CreateKiosks < ActiveRecord::Migration[7.1]
  def change
    create_table :kiosks do |t|
      t.string :name
      t.string :slug
      t.string :catalog_url

      t.timestamps
    end
    add_index :kiosks, :slug
  end
end
