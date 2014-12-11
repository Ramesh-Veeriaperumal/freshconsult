class AddAuthorityColumnsToUser < ActiveRecord::Migration
  shard :none
  def self.up
    Lhm.change_table :users, :atomic_switch => true do |m|
      m.add_column :helpdesk_agent, "tinyint(1) DEFAULT '0'"
      m.add_column :privileges, "varchar(255) DEFAULT '0'"
    end
  end

  def self.down
    Lhm.change_table :users, :atomic_switch => true do |m|
      m.remove_column :privileges
      m.remove_column :helpdesk_agent
    end
  end
end