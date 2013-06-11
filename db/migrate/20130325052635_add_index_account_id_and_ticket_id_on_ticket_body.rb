class AddIndexAccountIdAndTicketIdOnTicketBody < ActiveRecord::Migration
  def self.up
  	add_index :helpdesk_ticket_bodies, [:account_id, :ticket_id], :name => 'index_helpdesk_ticket_bodies_on_account_id_and_ticket_id'
  end

  def self.down
  	remove_index :helpdesk_ticket_bodies, [:account_id, :ticket_id]
  end
end
