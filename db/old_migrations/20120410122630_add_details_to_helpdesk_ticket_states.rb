class AddDetailsToHelpdeskTicketStates < ActiveRecord::Migration
  def self.up
    add_column :helpdesk_ticket_states, :status_updated_at, :datetime
    add_column :helpdesk_ticket_states, :sla_timer_stopped_at, :datetime
  end

  def self.down
    remove_column :helpdesk_ticket_states, :sla_timer_stopped_at
    remove_column :helpdesk_ticket_states, :status_updated_at
  end
end
