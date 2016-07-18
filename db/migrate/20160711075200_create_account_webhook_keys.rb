class CreateAccountWebhookKeys < ActiveRecord::Migration

	shard :all

  def self.up
  	create_table :account_webhook_keys do |t|
      t.integer :account_id, :limit => 8, :null => false
      t.string  :webhook_key, :limit => 15
      t.integer :vendor_id, :limit => 11
      t.integer :status, :limit => 1
    end 

    add_index :account_webhook_keys, [:account_id, :vendor_id], :name => 'index_account_webhook_keys_on_account_id_and_vendor_id'
    add_index :account_webhook_keys, :webhook_key, :unique => true
  end

  def self.down
  	drop_table :account_webhook_keys
  end
end
