class AddSessionsTable < ActiveRecord::Migration
  shard :all

  def self.up
    create_table :sessions do |t|
      t.string :session_id, null: false
      t.text :data
      t.integer :account_id, :limit => 8
      t.integer :user_id, :limit => 8

      t.timestamps
    end

    add_index :sessions, [:account_id, :session_id], name: 'index_sessions_on_account_id_and_session_id', unique: true
    add_index :sessions, [:account_id, :user_id], name: 'index_sessions_on_account_id_and_user_id'
    add_index :sessions, [:account_id, :updated_at], name: 'index_sessions_on_account_id_and_updated_at'
  end

  def self.down
    drop_table :sessions
  end
end
