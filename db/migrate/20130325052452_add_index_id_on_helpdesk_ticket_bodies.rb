class AddIndexIdOnHelpdeskTicketBodies < ActiveRecord::Migration
  def self.up
  	add_index :helpdesk_ticket_bodies, :id, :name => 'index_helpdesk_ticket_bodies_id'
  end

  def self.down
  	remove_index :helpdesk_ticket_bodies, :id
  end
end
