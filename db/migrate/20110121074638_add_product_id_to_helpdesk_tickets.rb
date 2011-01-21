class AddProductIdToHelpdeskTickets < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_tickets, :product_id, :integer
  end

  def self.down
    remove_column :helpdesk_tickets, :product_id
  end
end
