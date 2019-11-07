class AddTicketFieldIdToSections < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def self.up
    Lhm.change_table :helpdesk_sections, atomic_switch: true do |m|
      m.add_column :ticket_field_id, 'BIGINT'
      m.add_index [:account_id, :ticket_field_id], "index_helpdesk_sections_on_account_id_and_ticket_field_id"
    end
  end

  def self.down
    Lhm.change_table :helpdesk_sections, atomic_switch: true do |m|
      m.remove_index [:account_id, :ticket_field_id], "index_helpdesk_sections_on_account_id_and_ticket_field_id"
      m.remove_column :ticket_field_id
    end
  end
end