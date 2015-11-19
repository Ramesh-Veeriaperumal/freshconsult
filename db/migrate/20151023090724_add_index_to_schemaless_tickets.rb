class AddIndexToSchemalessTickets < ActiveRecord::Migration  

shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :helpdesk_schema_less_tickets, :atomic_switch => true do |m|
      m.add_index [:account_id, :boolean_tc04], 'index_helpdesk_schema_less_tickets_on_ticket_id_and_boolean_tc04'
      m.add_index [:account_id, :boolean_tc05], 'index_helpdesk_schema_less_tickets_on_ticket_id_and_boolean_tc05'
    end
  end

  def down
    Lhm.change_table :helpdesk_schema_less_tickets, :atomic_switch => true do |m|
      m.remove_index [:account_id, :boolean_tc04], 'index_helpdesk_schema_less_tickets_on_ticket_id_and_boolean_tc04'
      m.remove_index [:account_id, :boolean_tc05], 'index_helpdesk_schema_less_tickets_on_ticket_id_and_boolean_tc05'
    end
  end
end



end
