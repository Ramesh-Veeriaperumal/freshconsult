class CreateAccountWebhookKeys < ActiveRecord::Migration

	shard :all

  def self.up
  	create_table :account_webhook_keys do |t|
      t.integer :account_id, :limit => 8, :null => false
      t.string  :webhook_key
      t.integer :service_id, :limit => 11
      t.integer :status, :limit => 2
    end 

    add_index :account_webhook_keys, [:webhook_key], :name => 'index_account_webhook_keys_on_webhook_key'
  end

  def self.down
  	drop_table :account_webhook_keys
  end
end
