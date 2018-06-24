class CreateFreshconnectAccounts < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def self.up
    create_table :freshconnect_accounts do |t|
      t.column   :account_id, 'bigint unsigned'
      t.string   :product_account_id
      t.boolean  :enabled
      t.string 	 :freshconnect_domain
      t.timestamps
    end
    add_index :freshconnect_accounts, [:account_id], unique: true
  end

  def self.down
    drop_table :freshconnect_accounts
  end
end
