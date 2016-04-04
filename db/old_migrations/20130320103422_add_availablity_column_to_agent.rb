class AddAvailablityColumnToAgent < ActiveRecord::Migration
  def self.up
    # add_column :agents, :available, :boolean, :default => true
    Lhm.change_table :agents, :atomic_switch => true do |m|
       m.ddl("ALTER TABLE %s ADD COLUMN available tinyint(1) DEFAULT 1;" % m.name)
    end
  end

  def self.down
    # remove_column :agents, :available
    Lhm.change_table :agents, :atomic_switch => true do |m|
       m.ddl("ALTER TABLE %s DROP COLUMN available" % m.name)
    end
  end
end
