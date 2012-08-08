class CreateCustomerForums < ActiveRecord::Migration
  def self.up
    create_table :customer_forums do |t|
      t.column :customer_id , "bigint unsigned"
      t.column :forum_id , "bigint unsigned"
      t.column :account_id , "bigint unsigned"

      t.timestamps
    end

    add_index :customer_forums, [:account_id, :customer_id], :name => 'index_customer_forum_on_account_id_and_customer_id'
    add_index :customer_forums, [:account_id, :forum_id], :name => 'index_customer_forum_on_account_id_and_forum_id'
    
  end

  def self.down
    drop_table :customer_forums
  end
end
