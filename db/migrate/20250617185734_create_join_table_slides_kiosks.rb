class CreateJoinTableSlidesKiosks < ActiveRecord::Migration[7.1]
  def change
    create_join_table :slides, :kiosks do |t|
      # t.index [:slide_id, :kiosk_id]
      # t.index [:kiosk_id, :slide_id]
    end
  end
end
