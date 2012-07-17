class AddProductIdToHelpdeskTickets < ActiveRecord::Migration
  def self.up
  	add_column :helpdesk_tickets, :product_id, "bigint unsigned"

  	execute("update helpdesk_tickets h inner join email_configs e on  h.email_config_id = e.id and h.account_id = e.account_id set h.product_id = h.email_config_id where e.primary_role = 0")
  end

  def self.down
  	remove_column :helpdesk_tickets, :product_id
  end
end
