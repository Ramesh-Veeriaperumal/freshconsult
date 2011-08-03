class SetResolvedClosedState < ActiveRecord::Migration
  def self.up
    tkt_states = Helpdesk::TicketState.find(:all,:include => :tickets, :conditions => "resolved_at is not null || closed_at is not null")
    tkt_states.each do |tkt_state|
      tkt = tkt_state.tickets
      if tkt.open?
        tkt_state.resolved_at = nil
        tkt_state.closed_at = nil
      end
      tkt_state.resolved_at ||= tkt_state.closed_at
      tkt_state.save
    end
  end

  def self.down
  end
end
