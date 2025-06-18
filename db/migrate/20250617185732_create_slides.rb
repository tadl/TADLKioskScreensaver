class CreateSlides < ActiveRecord::Migration[7.1]
  def change
    create_table :slides do |t|
      t.string :title
      t.string :link
      t.integer :display_seconds
      t.date :start_date
      t.date :end_date

      t.timestamps
    end
  end
end
