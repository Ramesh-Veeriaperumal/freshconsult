class AddTicketFieldIdToPicklistValues < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def self.up
    Lhm.change_table :helpdesk_picklist_values, atomic_switch: true do |m|
      m.add_column :ticket_field_id, 'BIGINT'
      m.add_index [:account_id, :ticket_field_id], "index_picklist_values_on_account_id_and_ticket_field_id"
    end
  end

  def self.down
    Lhm.change_table :helpdesk_picklist_values, atomic_switch: true do |m|
      m.remove_index [:account_id, :ticket_field_id], "index_picklist_values_on_account_id_and_ticket_field_id"
      m.remove_column :ticket_field_id
    end
  end
end
