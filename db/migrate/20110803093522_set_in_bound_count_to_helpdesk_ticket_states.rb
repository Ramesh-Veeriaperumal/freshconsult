class SetInBoundCountToHelpdeskTicketStates < ActiveRecord::Migration
  def self.up
    tkt_states = Helpdesk::TicketState.find(:all)
    tkt_states.each do |tkt_state|
      inbound_count = tkt_state.tickets.notes.find(:all,:conditions => {:incoming => true}).count
      inbound_count ||= 0
      tkt_state.inbound_count = inbound_count + 1
      tkt_state.save
    end
  end

  def self.down
  end
end
