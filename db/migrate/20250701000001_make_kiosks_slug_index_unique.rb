# db/migrate/20250701000001_make_kiosks_slug_index_unique.rb
class MakeKiosksSlugIndexUnique < ActiveRecord::Migration[7.1]
  # must disable the wrapping transaction to use CONCURRENTLY
  disable_ddl_transaction!

  def change
    # remove the existing (non-unique) index
    remove_index :kiosks, :slug, algorithm: :concurrently

    # add a new UNIQUE index on slug
    add_index :kiosks, :slug, unique: true, algorithm: :concurrently
  end
end
