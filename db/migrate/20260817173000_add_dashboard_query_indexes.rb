class AddDashboardQueryIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :kiosk_sessions, :started_at,
      algorithm: :concurrently,
      if_not_exists: true
    add_index :kiosk_sessions, [:kiosk_code, :started_at],
      algorithm: :concurrently,
      if_not_exists: true
    add_index :kiosk_logs, [:kiosk_id, :occurred_at],
      order: { occurred_at: :desc },
      algorithm: :concurrently,
      if_not_exists: true
  end
end
