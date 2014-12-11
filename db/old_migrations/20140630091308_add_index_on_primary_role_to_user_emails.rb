class AddIndexOnPrimaryRoleToUserEmails < ActiveRecord::Migration
	shard :all
	def self.up
		Lhm.change_table :user_emails, :atomic_switch => true do |m|
	  		m.add_index [:user_id, :primary_role]
		end
	end

	def self.down
		Lhm.change_table :user_emails, :atomic_switch => true do |m|
	  		m.remove_index [:user_id, :primary_role]
		end
	end
end
