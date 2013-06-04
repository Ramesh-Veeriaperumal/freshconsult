class RemoveEscalateToFromSlaDetails < ActiveRecord::Migration
	def self.up
		Lhm.change_table :sla_details, :atomic_switch => true do |sd|
			sd.remove_column :escalateto
		end
	end

	def self.down
		Lhm.change_table :sla_details, :atomic_switch => true do |sd|
			sd.add_column :escalateto, "bigint unsigned"
		end
	end
end
