class CreateEcommerceAccountsTable < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :ecommerce_accounts do |t|
      t.string   :name 
      t.text     :configs
      t.string   :type
      t.integer  :account_id, :limit => 8
      t.integer  :group_id, :limit => 8
      t.integer  :product_id, :limit => 8
      t.string   :external_account_id
      t.integer  :status, :default => 1 
      t.datetime :last_sync_time
      t.boolean  :reauth_required,  :default => false
      t.timestamps
    end
    add_index :ecommerce_accounts, [:account_id], :name => 'index_ecommerce_accounts_on_account_id'
    add_index :ecommerce_accounts, [:account_id,:external_account_id], :name => 'index_ecommerce_accounts_on_account_id_and_external_account_id'
  end


  def down
  	drop_table :ecommerce_accounts
  end
end