class AddFallbackToSlides < ActiveRecord::Migration[7.1]
  def change
    add_column :slides, :fallback, :boolean, null: false, default: false
  end
end
