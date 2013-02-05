class AddTimeColumnsToTicketStates < ActiveRecord::Migration
  def self.up
  	add_column :helpdesk_ticket_states, :first_resp_time_by_bhrs, :integer
    add_column :helpdesk_ticket_states, :resolution_time_by_bhrs, :integer
    add_column :helpdesk_ticket_states, :avg_response_time_by_bhrs, :float
  end

  def self.down
  	remove_column :helpdesk_ticket_states, :avg_response_time_by_bhrs
    remove_column :helpdesk_ticket_states, :resolution_time_by_bhrs
    remove_column :helpdesk_ticket_states, :first_resp_time_by_bhrs
  end
end
