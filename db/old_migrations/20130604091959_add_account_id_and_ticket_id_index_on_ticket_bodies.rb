class AddAccountIdAndTicketIdIndexOnTicketBodies < ActiveRecord::Migration
  shard :none
  def self.up
  	remove_index :helpdesk_ticket_bodies, [:account_id, :ticket_id]
  	add_index :helpdesk_ticket_bodies, [:account_id, :ticket_id], :name => 'index_ticket_bodies_on_account_id_and_ticket_id', :unique => true
  end

  def self.down
  	remove_index :helpdesk_ticket_bodies, [:account_id, :ticket_id]
  end
end
