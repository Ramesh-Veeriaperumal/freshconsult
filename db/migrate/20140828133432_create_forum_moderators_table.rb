class CreateForumModeratorsTable < ActiveRecord::Migration
	shard :all
	def self.up
		create_table :forum_moderators do |t|
			t.column :account_id, "bigint unsigned"
			t.column :moderator_id, "bigint unsigned"
		end

		add_index :forum_moderators, [:account_id, :moderator_id], :name => 'index_forum_moderators_on_account_id_and_moderator_id', :unique => true
	end

	def self.down
		drop_table :forum_moderators
	end
end

