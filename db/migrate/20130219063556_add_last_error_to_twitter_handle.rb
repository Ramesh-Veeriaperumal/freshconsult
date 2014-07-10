class AddLastErrorToTwitterHandle < ActiveRecord::Migration
  def self.up
  	add_column :social_twitter_handles, :last_error, :text
  end

  def self.down
  	remove_column :social_twitter_handles, :last_error
  end
end
