class CreateEcommerceAccountsTable < ActiveRecord::Migration
  shard :all

  def up
    create_table :ecommerce_accounts do |t|
      t.string   :name 
      t.text     :configs
      t.integer  :email_config_id, :limit => 8
      t.string   :type
      t.integer  :account_id, :limit => 8
      t.string   :external_account_id
      t.boolean  :active, :default => false
      t.timestamps
    end
    add_index :ecommerce_accounts, [:account_id, :email_config_id], :name => 'index_ecommerce_accounts_on_account_id_and_email_config_id'
  end


  def down
  	drop_table :ecommerce_accounts
  end
end