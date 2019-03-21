class AddClosedAtAndResolvedAtIndexToTicketStates < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    safe_send(direction)
  end

  def up
    Lhm.change_table :helpdesk_ticket_states, atomic_switch: true do |m|
      m.add_index [:account_id, :closed_at], 'index_on_helpdesk_ticket_states_account_id_and_closed_at'
      m.add_index [:account_id, :resolved_at], 'index_on_helpdesk_ticket_states_account_id_and_resolved_at'
    end
  end

  def down
    Lhm.change_table :helpdesk_ticket_states, atomic_switch: true do |m|
      m.remove_index [:account_id, :closed_at], 'index_on_helpdesk_ticket_states_account_id_and_closed_at'
      m.remove_index [:account_id, :resolved_at], 'index_on_helpdesk_ticket_states_account_id_and_resolved_at'
    end
  end
end
