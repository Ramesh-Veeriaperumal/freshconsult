class AddNexResponseSlaFields < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
  	Lhm.change_table :helpdesk_tickets, :atomic_switch => true do |m|
      m.add_column :nr_due_by, :datetime
      m.add_column :nr_reminded, "tinyint(1)"
      m.add_column :nr_escalated, "tinyint(1)"
      m.add_column :int_tc01, :integer
      m.add_column :int_tc02, :integer
      m.add_column :int_tc03, :integer
      m.add_column :int_tc04, :integer
      m.add_column :int_tc05, :integer
      m.add_column :long_tc01, "bigint(20)"
      m.add_column :long_tc02, "bigint(20)"
      m.add_column :long_tc03, "bigint(20)"
      m.add_column :long_tc04, "bigint(20)"
      m.add_column :long_tc05, "bigint(20)"
      m.add_column :datetime_tc01, :datetime
      m.add_column :datetime_tc02, :datetime
      m.add_column :datetime_tc03, :datetime
      m.add_column :json_tc01, :json
      m.add_index [:account_id, :frDueBy], 'index_helpdesk_tickets_on_account_id_and_frDueBy'
      m.add_index [:account_id, :nr_due_by], 'index_helpdesk_tickets_on_account_id_and_nr_due_by'
    end

    execute "drop trigger add_ticket_display_id"
    ActiveRecord::Base.connection.execute(TriggerSql.sql_for_populating_ticket_display_id)

    Lhm.change_table :sla_details, :atomic_switch => true do |m|
      m.add_column :next_response_time, :integer
    end
  end

  def down
    Lhm.change_table :helpdesk_tickets, :atomic_switch => true do |m|
    	m.remove_column :nr_due_by
      m.remove_column :nr_reminded
      m.remove_column :nr_escalated
      m.remove_column :int_tc01
      m.remove_column :int_tc02
      m.remove_column :int_tc03
      m.remove_column :int_tc04
      m.remove_column :int_tc05
      m.remove_column :long_tc01
      m.remove_column :long_tc02
      m.remove_column :long_tc03
      m.remove_column :long_tc04
      m.remove_column :long_tc05
      m.remove_column :json_tc01
      m.remove_column :datetime_tc01
      m.remove_column :datetime_tc02
      m.remove_column :datetime_tc03
      m.remove_index [:account_id, :frDueBy], 'index_helpdesk_tickets_on_account_id_and_frDueBy'
      m.remove_index [:account_id, :nr_due_by], 'index_helpdesk_tickets_on_account_id_and_nr_due_by'
    end

    execute "drop trigger add_ticket_display_id"
    ActiveRecord::Base.connection.execute(TriggerSql.sql_for_populating_ticket_display_id)

    Lhm.change_table :sla_details, :atomic_switch => true do |m|
      m.remove_column :next_response_time
    end
  end
end
