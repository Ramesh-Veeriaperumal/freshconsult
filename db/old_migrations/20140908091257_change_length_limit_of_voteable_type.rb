class ChangeLengthLimitOfVoteableType < ActiveRecord::Migration
	shard :all
	def self.up
		Lhm.change_table :votes, :atomic_switch => true do |m|
			m.change_column :voteable_type, "VARCHAR(30)"
		end
	end

	def self.down
		Lhm.change_table :votes, :atomic_switch => true do |m|
			m.change_column :voteable_type, "VARCHAR(15)"
		end
	end
end
