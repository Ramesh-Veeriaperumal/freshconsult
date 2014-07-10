class AddOutboundCountAndAvgRespTimeToTicketStates < ActiveRecord::Migration
  def self.up
  	add_column :helpdesk_ticket_states, :outbound_count, :integer, :default => 0
    add_column :helpdesk_ticket_states, :avg_response_time, :float
  end

  def self.down
  	remove_column :helpdesk_ticket_states, :avg_response_time
    remove_column :helpdesk_ticket_states, :outbound_count
  end
end
