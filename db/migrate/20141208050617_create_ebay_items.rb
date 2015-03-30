class CreateEbayItems < ActiveRecord::Migration
	shard :all

  def up
  	create_table :ebay_items do |t|
      t.string  :user_id, :limit => 8  
      t.integer :message_id, :limit => 8  
      t.integer :item_id, :limit => 8
      t.integer :ticket_id, :limit => 8
      t.integer :ebay_acc_id, :limit => 8	
      t.integer :account_id, :limit => 8
      t.timestamps
    end
    add_index :ebay_items, [:account_id,:user_id, :item_id], :name => 'index_ebay_items_on_account_id_and_user_id_and_item_id'
    add_index :ebay_items, [:account_id,:ebay_acc_id], :name => 'index_ebay_items_on_account_id_and_ebay_account_id'
  end

  def down
  	drop_table :ebay_items
  end
end
