class AddMergedToTopics < ActiveRecord::Migration
	shard :all
	
	def self.up
		Lhm.change_table :topics, :atomic_switch => true do |m|
			m.add_column :merged_topic_id, "bigint DEFAULT NULL"
		end
	end

	def self.down
		Lhm.change_table :topics, :atomic_switch => true do |m|
			m.remove_column :merged_topic_id
		end
	end
end