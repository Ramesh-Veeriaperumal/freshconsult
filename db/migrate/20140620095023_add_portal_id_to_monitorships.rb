class AddPortalIdToMonitorships < ActiveRecord::Migration
	shard :all
	
  def self.up
		Lhm.change_table :monitorships, :atomic_switch => true do |m|
			m.add_column :portal_id, "bigint DEFAULT NULL"
		end
  end

  def self.down
		Lhm.change_table :monitorships, :atomic_switch => true do |m|
			m.remove_column :portal_id
		end
  end
end