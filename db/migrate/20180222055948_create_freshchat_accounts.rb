class CreateFreshchatAccounts < ActiveRecord::Migration
  shard :all
  
  def migrate(direction)
    self.send(direction)
  end

  def self.up
    create_table :freshchat_accounts do |t|
      t.column   :account_id, "bigint unsigned"
      t.string   :app_id
      t.text     :preferences
      t.boolean  :enabled
      t.timestamps
    end
    add_index :freshchat_accounts, [ :account_id ], :unique => true
  end

  def self.down
    drop_table :freshchat_accounts
  end
end

