class AddStateToTwitterHandle < ActiveRecord::Migration
  def self.up
  	add_column :social_twitter_handles, :state, :integer
  end

  def self.down
  	remove_column :social_twitter_handles, :state
  end
end
