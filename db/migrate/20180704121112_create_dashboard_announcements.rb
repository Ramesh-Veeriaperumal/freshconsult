class CreateDashboardAnnouncements < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    safe_send(direction)
  end

  def up
    create_table :dashboard_announcements do |t|
      t.integer :account_id, limit: 8
      t.integer :dashboard_id, limit: 8
      t.integer :user_id, limit: 8
      t.text :announcement_text
      t.boolean :active, default: true

      t.timestamps
    end

    add_index :dashboard_announcements, [:account_id, :dashboard_id], name: 'index_account_id_dashboard_id'
  end

  def down
    drop_table :dashboard_announcements
  end
end
