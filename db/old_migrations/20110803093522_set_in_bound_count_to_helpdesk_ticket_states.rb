class SetInBoundCountToHelpdeskTicketStates < ActiveRecord::Migration
  def self.up
    Account.find(:all,:conditions => "id != 498 ").each do |account|
      tkts = account.tickets
      tkts.each do |tkt|
        begin
          inbound_count = tkt.notes.count(:all,:conditions => {:incoming => true})
          inbound_count ||= 0
          tkt_state = tkt.ticket_states
          tkt_state.inbound_count = inbound_count + 1
          tkt_state.assigned_at ||= tkt_state.created_at if tkt.responder_id.blank?
          tkt_state.first_assigned_at  ||= tkt_state.created_at if tkt.responder_id.blank?
          tkt_state.pending_since  ||= tkt_state.created_at if tkt.pending?
          tkt_state.resolved_at   ||= tkt_state.created_at if tkt.resolved?
          tkt_state.resolved_at ||= tkt_state.closed_at  ||= tkt_state.created_at if tkt.closed? 
          tkt_state.save
          rescue
            puts "Error in ticket state migration!"
          end
      end
    end
  end

  def self.down
  end
end
