class AddIndexToTicketStates < ActiveRecord::Migration
  shard :all

  def migrate(direction)
  	self.send(direction)
  end

  def up
  	Lhm.change_table :helpdesk_ticket_states, :atomic_switch => true do |m|
      m.add_index [:account_id,:ticket_id,:ts_datetime1], 'index_on_account_id_and_ticket_id_and_ts_datetime1'
    end
  end

  def down
    Lhm.change_table :helpdesk_ticket_states, :atomic_switch => true do |m|
      m.remove_index [:account_id,:ticket_id,:ts_datetime1], 'index_on_account_id_and_ticket_id_and_ts_datetime1'
    end
  end
end
