class UpdateIndexForHelpdeskTicketFields < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :helpdesk_ticket_fields, atomic_switch: true do |m|
      m.add_index [:account_id, :flexifield_def_entry_id], 'index_ticket_fields_on_account_id_and_flexifield_def_entry_id'
    end
  end

  def down
    Lhm.change_table :helpdesk_ticket_fields, atomic_switch: true do |m|
      m.remove_index [:account_id, :flexifield_def_entry_id], 'index_ticket_fields_on_account_id_and_flexifield_def_entry_id'
    end
  end
end
