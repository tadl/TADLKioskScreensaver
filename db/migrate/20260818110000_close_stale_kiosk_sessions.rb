class CloseStaleKioskSessions < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE kiosk_sessions
      SET ended_at = started_at + INTERVAL '12 hours',
          updated_at = CURRENT_TIMESTAMP
      WHERE ended_at IS NULL
        AND started_at < CURRENT_TIMESTAMP - INTERVAL '12 hours'
    SQL
  end

  def down
    # The original missing end time cannot be reconstructed safely.
  end
end
