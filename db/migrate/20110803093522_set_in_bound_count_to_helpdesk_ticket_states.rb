class SetInBoundCountToHelpdeskTicketStates < ActiveRecord::Migration
  def self.up
    tkt_states = Helpdesk::TicketState.find(:all)
    tkt_states.each do |tkt_state|
      inbound_count = tkt_state.tickets.notes.find(:all,:conditions => {:incoming => true}).count
      inbound_count ||= 0
      tkt_state.inbound_count = inbound_count + 1
      tkt_state.opened_at ||= tkt_state.created_at
      tkt_state.assigned_at ||= tkt_state.created_at if tkt_states.tickets.responder_id
      tkt_state.first_assigned_at  ||= tkt_state.created_at if tkt_states.tickets.responder_id
      tkt_state.pending_since  ||= tkt_state.created_at if tkt_states.tickets.pending?
      tkt_state.resolved_at   ||= tkt_state.created_at if tkt_states.tickets.resolved?
      tkt_state.resolved_at ||= tkt_state.closed_at  ||= tkt_state.created_at if tkt_state.tickets.closed?      
      tkt_state.save
    end
  end

  def self.down
  end
end
