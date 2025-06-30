class AddIndexToKiosksSlug < ActiveRecord::Migration[7.1]
  def change
    unless index_exists?(:kiosks, :slug)
      add_index :kiosks, :slug, unique: true
    end
  end
end
