class RemoveProductIdFromHelpdeskTickets < ActiveRecord::Migration
  def self.up
		remove_column :helpdesk_tickets, :product_id
  end

  def self.down
  end
end
