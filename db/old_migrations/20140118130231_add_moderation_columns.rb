class AddModerationColumns < ActiveRecord::Migration

	shard :all

	def self.up
		Lhm.change_table :topics, :atomic_switch => true do |m|
		  m.add_column :published, "tinyint(1) DEFAULT '0'"
		  m.add_index [:forum_id, :published]
		end
		execute("UPDATE topics SET published=1")

		Lhm.change_table :posts, :atomic_switch => true do |m|
			m.add_column :published, "tinyint(1) DEFAULT '0'"
			m.add_column :spam, "tinyint(1)"
			m.add_index [:topic_id, :published]
			m.add_index [:topic_id, :spam]
		end
		execute("UPDATE posts SET published=1")

	end

	def self.down
		Lhm.change_table :topics, :atomic_switch => true do |m|
		  m.remove_index [:forum_id, :published]
		  m.remove_column :published
		end

		Lhm.change_table :posts, :atomic_switch => true do |m|
			m.remove_index [:topic_id, :published]
			m.remove_index [:topic_id, :spam]
		  m.remove_column :published
		  m.remove_column :spam
		end
	end
end
