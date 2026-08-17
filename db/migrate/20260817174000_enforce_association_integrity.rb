class EnforceAssociationIntegrity < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    consolidate_duplicate_permissions
    consolidate_duplicate_user_permissions
    clean_join_table(:kiosks_slides, :kiosk_id, :kiosks, :slide_id, :slides)
    clean_join_table(
      :kiosk_groups_user_permissions,
      :user_permission_id,
      :user_permissions,
      :kiosk_group_id,
      :kiosk_groups
    )
    clean_join_table(
      :kiosks_user_permissions,
      :user_permission_id,
      :user_permissions,
      :kiosk_id,
      :kiosks
    )
    close_duplicate_open_sessions

    add_integrity_indexes
    add_integrity_foreign_keys
  end

  def down
    remove_foreign_key :kiosks_slides, column: :kiosk_id
    remove_foreign_key :kiosks_slides, column: :slide_id
    remove_foreign_key :kiosk_groups_user_permissions, column: :user_permission_id
    remove_foreign_key :kiosk_groups_user_permissions, column: :kiosk_group_id
    remove_foreign_key :kiosks_user_permissions, column: :user_permission_id
    remove_foreign_key :kiosks_user_permissions, column: :kiosk_id

    remove_index :kiosk_sessions, name: :index_kiosk_sessions_on_open_host
    remove_index :permissions, name: :index_permissions_on_name
    remove_index :user_permissions, name: :index_user_permissions_on_user_and_permission
    remove_index :kiosks_slides, name: :index_kiosks_slides_on_kiosk_and_slide
    remove_index :kiosks_slides, name: :index_kiosks_slides_on_slide_and_kiosk
    remove_index :kiosk_groups_user_permissions, name: :index_group_permissions_on_permission_and_group
    remove_index :kiosk_groups_user_permissions, name: :index_group_permissions_on_group_and_permission
  end

  private

  def consolidate_duplicate_permissions
    execute <<~SQL.squish
      UPDATE user_permissions AS user_permission
      SET permission_id = canonical.keep_id
      FROM (
        SELECT name, MIN(id) AS keep_id, ARRAY_AGG(id) AS permission_ids
        FROM permissions
        GROUP BY name
        HAVING COUNT(*) > 1
      ) AS canonical
      WHERE user_permission.permission_id = ANY(canonical.permission_ids)
        AND user_permission.permission_id <> canonical.keep_id
    SQL

    execute <<~SQL.squish
      DELETE FROM permissions AS permission
      USING permissions AS keeper
      WHERE permission.name = keeper.name
        AND permission.id > keeper.id
    SQL
  end

  def consolidate_duplicate_user_permissions
    execute <<~SQL.squish
      INSERT INTO kiosk_groups_user_permissions (user_permission_id, kiosk_group_id)
      SELECT duplicate.keep_id, assignment.kiosk_group_id
      FROM (
        SELECT id, MIN(id) OVER (PARTITION BY user_id, permission_id) AS keep_id
        FROM user_permissions
      ) AS duplicate
      JOIN kiosk_groups_user_permissions AS assignment
        ON assignment.user_permission_id = duplicate.id
      WHERE duplicate.id <> duplicate.keep_id
    SQL

    execute <<~SQL.squish
      INSERT INTO kiosks_user_permissions (user_permission_id, kiosk_id)
      SELECT duplicate.keep_id, assignment.kiosk_id
      FROM (
        SELECT id, MIN(id) OVER (PARTITION BY user_id, permission_id) AS keep_id
        FROM user_permissions
      ) AS duplicate
      JOIN kiosks_user_permissions AS assignment
        ON assignment.user_permission_id = duplicate.id
      WHERE duplicate.id <> duplicate.keep_id
      ON CONFLICT DO NOTHING
    SQL

    execute <<~SQL.squish
      DELETE FROM user_permissions AS user_permission
      USING user_permissions AS keeper
      WHERE user_permission.user_id = keeper.user_id
        AND user_permission.permission_id = keeper.permission_id
        AND user_permission.id > keeper.id
    SQL
  end

  def clean_join_table(table, left_column, left_table, right_column, right_table)
    execute <<~SQL.squish
      DELETE FROM #{quote_table_name(table)} AS assignment
      WHERE NOT EXISTS (
        SELECT 1 FROM #{quote_table_name(left_table)}
        WHERE #{quote_table_name(left_table)}.id = assignment.#{quote_column_name(left_column)}
      ) OR NOT EXISTS (
        SELECT 1 FROM #{quote_table_name(right_table)}
        WHERE #{quote_table_name(right_table)}.id = assignment.#{quote_column_name(right_column)}
      )
    SQL

    execute <<~SQL.squish
      DELETE FROM #{quote_table_name(table)} AS assignment
      USING #{quote_table_name(table)} AS keeper
      WHERE assignment.#{quote_column_name(left_column)} = keeper.#{quote_column_name(left_column)}
        AND assignment.#{quote_column_name(right_column)} = keeper.#{quote_column_name(right_column)}
        AND assignment.ctid > keeper.ctid
    SQL
  end

  def close_duplicate_open_sessions
    execute <<~SQL.squish
      WITH duplicates AS (
        SELECT id,
          ROW_NUMBER() OVER (
            PARTITION BY kiosk_code, host
            ORDER BY started_at DESC, id DESC
          ) AS position
        FROM kiosk_sessions
        WHERE ended_at IS NULL AND host IS NOT NULL
      )
      UPDATE kiosk_sessions
      SET ended_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
      FROM duplicates
      WHERE kiosk_sessions.id = duplicates.id
        AND duplicates.position > 1
    SQL
  end

  def add_integrity_indexes
    add_index :permissions, :name,
      unique: true, algorithm: :concurrently, if_not_exists: true
    add_index :user_permissions, [:user_id, :permission_id],
      unique: true,
      name: :index_user_permissions_on_user_and_permission,
      algorithm: :concurrently,
      if_not_exists: true
    add_index :kiosks_slides, [:kiosk_id, :slide_id],
      unique: true,
      name: :index_kiosks_slides_on_kiosk_and_slide,
      algorithm: :concurrently,
      if_not_exists: true
    add_index :kiosks_slides, [:slide_id, :kiosk_id],
      name: :index_kiosks_slides_on_slide_and_kiosk,
      algorithm: :concurrently,
      if_not_exists: true
    add_index :kiosk_groups_user_permissions, [:user_permission_id, :kiosk_group_id],
      unique: true,
      name: :index_group_permissions_on_permission_and_group,
      algorithm: :concurrently,
      if_not_exists: true
    add_index :kiosk_groups_user_permissions, [:kiosk_group_id, :user_permission_id],
      name: :index_group_permissions_on_group_and_permission,
      algorithm: :concurrently,
      if_not_exists: true
    add_index :kiosk_sessions, [:kiosk_code, :host],
      unique: true,
      where: "ended_at IS NULL AND host IS NOT NULL",
      name: :index_kiosk_sessions_on_open_host,
      algorithm: :concurrently,
      if_not_exists: true
  end

  def add_integrity_foreign_keys
    add_and_validate_foreign_key :kiosks_slides, :kiosks, column: :kiosk_id
    add_and_validate_foreign_key :kiosks_slides, :slides, column: :slide_id
    add_and_validate_foreign_key :kiosk_groups_user_permissions, :user_permissions, column: :user_permission_id
    add_and_validate_foreign_key :kiosk_groups_user_permissions, :kiosk_groups, column: :kiosk_group_id
    add_and_validate_foreign_key :kiosks_user_permissions, :user_permissions, column: :user_permission_id
    add_and_validate_foreign_key :kiosks_user_permissions, :kiosks, column: :kiosk_id
  end

  def add_and_validate_foreign_key(from_table, to_table, column:)
    add_foreign_key from_table, to_table, column: column, validate: false
    validate_foreign_key from_table, to_table, column: column
  end
end
