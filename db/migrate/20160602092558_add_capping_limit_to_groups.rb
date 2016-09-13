class AddCappingLimitToGroups < ActiveRecord::Migration
  shard :all

  def self.up
    Lhm.change_table :groups, :atomic_switch => true do |m|
      m.add_column :capping_limit, "integer DEFAULT '0'"
    end
  end

  def self.down
    Lhm.change_table :groups, :atomic_switch => true do |m|
      m.remove_column :capping_limit
    end
  end
end
