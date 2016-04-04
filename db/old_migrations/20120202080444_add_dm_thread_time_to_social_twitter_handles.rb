class AddDmThreadTimeToSocialTwitterHandles < ActiveRecord::Migration
  def self.up
    add_column :social_twitter_handles, :dm_thread_time, :integer ,:default => 0
  end

  def self.down
    remove_column :social_twitter_handles, :dm_thread_time
  end
end
