class DropAccountIndexOnTicketStates < ActiveRecord::Migration
  def self.up
  	Lhm.change_table :helpdesk_ticket_states, :atomic_switch => true do |m|
       m.ddl("ALTER TABLE %s DROP INDEX index_helpdesk_ticket_states_on_account_id" % m.name)
    end
  end

  def self.down
  	Lhm.change_table :helpdesk_ticket_states, :atomic_switch => true do |m|
       m.ddl("ALTER TABLE %s ADD INDEX index_helpdesk_ticket_states_on_account_id(account_id)" % m.name)
    end
  end
end
