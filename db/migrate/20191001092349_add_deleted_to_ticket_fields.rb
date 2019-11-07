class AddDeletedToTicketFields < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :helpdesk_ticket_fields, :atomic_switch => true do |m|
      m.add_column :deleted, 'tinyint(1) DEFAULT 0'
    end
  end

  def down
    Lhm.change_table :helpdesk_ticket_fields, :atomic_switch => true do |m|
      m.remove_column :deleted
    end
  end
end
