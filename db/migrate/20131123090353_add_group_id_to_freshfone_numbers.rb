class AddGroupIdToFreshfoneNumbers < ActiveRecord::Migration
	shard :none
	def self.up
		add_column :freshfone_numbers, :group_id, "bigint unsigned"
	end

	def self.down
		remove_column :freshfone_numbers, :group_id
	end
end
