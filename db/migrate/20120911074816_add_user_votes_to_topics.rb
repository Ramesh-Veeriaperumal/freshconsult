class AddUserVotesToTopics < ActiveRecord::Migration
  def self.up
  	add_column :topics, :user_votes, :integer, :default => 0
  end

  def self.down
  	remove_column :topics, :user_votes
  end
end
