class RemoveProductTables < ActiveRecord::Migration
  def self.up
    remove_column :helpdesk_tickets, :product_id
    drop_table :products
  end

  def self.down
  end
end
