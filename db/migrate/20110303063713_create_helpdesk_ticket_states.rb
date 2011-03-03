class CreateHelpdeskTicketStates < ActiveRecord::Migration
  def self.up
    create_table :helpdesk_ticket_states do |t|
      t.integer  :ticket_id ,:limit => 8
      t.datetime :opened_at
      t.datetime :pending_since
      t.datetime :resolved_at
      t.datetime :closed_at
      t.datetime :first_asigned_at
      t.datetime :assigned_at
      t.datetime :first_response_time
      t.datetime :requester_responded_at
      t.datetime :agent_responded_at

      t.timestamps
    end
  end

  def self.down
    drop_table :helpdesk_ticket_states
  end
end
