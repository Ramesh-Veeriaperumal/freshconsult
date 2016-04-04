class AddIndexForHelpdeskTicketStatesOnTicketId < ActiveRecord::Migration
  def self.up
    add_index :helpdesk_ticket_states, :ticket_id, :name => 'index_helpdesk_ticket_states_on_ticket_id'
  end

  def self.down
    remove_index(:helpdesk_ticket_states, :name => 'index_helpdesk_ticket_states_on_ticket_id')
  end
end
