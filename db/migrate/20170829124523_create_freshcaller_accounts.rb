class CreateFreshcallerAccounts < ActiveRecord::Migration
  shard :all
  def self.up
    create_table :freshcaller_accounts do |t|
      t.references :account, :limit => 8
      t.integer :freshcaller_account_id, :limit => 8
      t.string :domain
      t.timestamps
    end
    add_index :freshcaller_accounts, :account_id
  end

  def self.down
    drop_table :freshcaller_accounts
  end
end
