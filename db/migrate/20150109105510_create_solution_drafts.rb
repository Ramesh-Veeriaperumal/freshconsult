class CreateSolutionDrafts < ActiveRecord::Migration
	shard :all

	def migrate(direction)
		create_table :solution_drafts do |t|
			t.integer  "account_id",   :limit => 8, :null => false
			t.integer  "article_id",   :limit => 8
			t.string   "title"
			t.integer  "user_id", :limit => 8
			t.text		"meta"
			t.integer  "status"
			t.timestamp "modified_at"
			t.timestamps
		end
	end

	# def self.down
	# 	drop_table :solution_drafts
	# end
end
