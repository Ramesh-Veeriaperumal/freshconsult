class ModifyIndexesForTicket < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :helpdesk_tickets, :atomic_switch => true do |m|
      m.add_column :dirty, "int(11) DEFAULT '0'"
      m.add_column :parent_ticket_id, "bigint(20) DEFAULT NULL"
      m.add_column :sl_product_id, "bigint(20) DEFAULT NULL"
      m.add_column :sl_sla_policy_id, "bigint(20) DEFAULT NULL"
      m.add_column :sl_merge_parent_ticket, "bigint(20) DEFAULT NULL"

      m.add_column :sl_skill_id, "bigint(20) DEFAULT NULL"
      m.add_column :st_survey_rating, "bigint(20) DEFAULT NULL"
      m.add_column :sl_escalation_level, "bigint(20) DEFAULT NULL"
      m.add_column :sl_manual_dueby, "bigint(20) DEFAULT NULL"

      m.add_column :internal_group_id, "bigint(20) DEFAULT NULL"
      m.add_column :internal_agent_id, "bigint(20) DEFAULT NULL"
      m.add_column :association_type, "bigint(20) DEFAULT NULL"
      m.add_column :associates_rdb, "bigint(20) DEFAULT NULL"
      m.add_column :sla_state, "int(11) DEFAULT NULL"

      m.add_index [:account_id, :responder_id, :status, :created_at], "index_account_id_and_responder_id_and_status_created_at"
      m.add_index [:account_id, :responder_id, :created_at], "index_account_id_and_responder_id_and_created_at"
      m.add_index [:account_id, :group_id], "index_account_id_group_id"
      m.add_index [:account_id, :requester_id,:updated_at], "index_account_id_requester_id_updated_at"

      m.remove_index [:requester_id, :account_id]
      m.remove_index [:responder_id, :account_id]
    end
  end


  def down
     Lhm.change_table :helpdesk_tickets, :atomic_switch => true do |m|
      m.remove_column :dirty
      m.remove_column :parent_ticket_id
      m.remove_column :sl_product_id
      m.remove_column :sl_sla_policy_id
      m.remove_column :sl_merge_parent_ticket

      m.remove_column :sl_skill_id
      m.remove_column :st_survey_rating
      m.remove_column :sl_escalation_level
      m.remove_column :sl_manual_dueby

      m.remove_column :internal_group_id
      m.remove_column :internal_agent_id
      m.remove_column :association_type
      m.remove_column :associates_rdb
      m.remove_column :sla_state

      m.remove_index [:account_id, :responder_id, :status, :created_at]
      m.remove_index [:account_id, :responder_id, :created_at]
      m.remove_index [:account_id, :group_id]
      m.remove_index [:account_id, :requester_id,:updated_at]

      m.add_index [:requester_id, :account_id], "index_helpdesk_tickets_on_requester_id_and_account_id"
      m.add_index [:responder_id, :account_id], "index_helpdesk_tickets_on_responder_id_and_account_id"
    end
  end
end


class AddColumnsToFlexifield < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :flexifields, :atomic_switch => true do |m|
      m.add_column :ff_boolean11, "tinyint(1) DEFAULT '0'"
      m.add_column :ff_boolean12, "tinyint(1) DEFAULT '0'"
      m.add_column :ff_boolean13, "tinyint(1) DEFAULT '0'"
      m.add_column :ff_boolean14, "tinyint(1) DEFAULT '0'"
      m.add_column :ff_boolean15, "tinyint(1) DEFAULT '0'"
      m.add_column :ff_boolean16, "tinyint(1) DEFAULT '0'"
      m.add_column :ff_boolean17, "tinyint(1) DEFAULT '0'"
      m.add_column :ff_boolean18, "tinyint(1) DEFAULT '0'"
      m.add_column :ff_boolean19, "tinyint(1) DEFAULT '0'"
      m.add_column :ff_boolean20, "tinyint(1) DEFAULT '0'"
    end
  end


  def down
     Lhm.change_table :flexifields, :atomic_switch => true do |m|
      m.remove_column :ff_boolean11
      m.remove_column :ff_boolean12
      m.remove_column :ff_boolean13
      m.remove_column :ff_boolean14
      m.remove_column :ff_boolean15
      m.remove_column :ff_boolean16
      m.remove_column :ff_boolean17
      m.remove_column :ff_boolean18
      m.remove_column :ff_boolean19
      m.remove_column :ff_boolean20
      
    end
  end
end

class AddColumnsToHelpdeskTicketStates < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :helpdesk_ticket_states, :atomic_switch => true do |m|
      m.add_column :ts_datetime1, "datetime DEFAULT NULL"
      m.add_column :ts_datetime2, "datetime DEFAULT NULL"
      m.add_column :ts_datetime3, "datetime DEFAULT NULL"
      m.add_column :ts_datetime4, "datetime DEFAULT NULL"
      m.add_column :ts_int1, "int(11) DEFAULT NULL"
      m.add_column :ts_int2, "int(11) DEFAULT NULL"
      m.add_column :ts_int3, "int(11) DEFAULT NULL"
      m.add_column :resolution_time_updated_at, "datetime DEFAULT NULL"

      m.add_index [:id, :requester_responded_at], "index_id_and_requester_responded_at"
      m.add_index [:id, :agent_responded_at], "index_id_and_agent_responded_at"

    end
  end


  def down
     Lhm.change_table :helpdesk_ticket_states, :atomic_switch => true do |m|
      m.remove_column :ts_datetime1
      m.remove_column :ts_datetime2
      m.remove_column :ts_datetime3
      m.remove_column :ts_datetime4
      m.remove_column :ts_int1
      m.remove_column :ts_int2
      m.remove_column :ts_int3
      m.remove_column :resolution_time_updated_at

      m.remove_index [:id, :requester_responded_at]
      m.remove_index [:id, :agent_responded_at]
    end
  end
end



