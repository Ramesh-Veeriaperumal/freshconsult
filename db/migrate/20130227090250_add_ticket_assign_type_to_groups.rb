class AddTicketAssignTypeToGroups < ActiveRecord::Migration
  def self.up
    # add_column :groups, :ticket_assign_type, :integer, :default => 0
    Lhm.change_table :groups, :atomic_switch => true do |m|
       m.ddl("ALTER TABLE  %s add COLUMN ticket_assign_type integer(11) DEFAULT 0" % m.name)
    end
  end

  def self.down
    # remove_column :groups, :ticket_assign_type
    Lhm.change_table :groups, :atomic_switch => true do |m|
       m.ddl("ALTER TABLE %s DROP COLUMN ticket_assign_type" % m.name)
    end
  end
end
