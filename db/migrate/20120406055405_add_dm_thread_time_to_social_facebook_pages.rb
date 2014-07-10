class AddDmThreadTimeToSocialFacebookPages < ActiveRecord::Migration
  def self.up
    add_column :social_facebook_pages, :dm_thread_time, :integer ,:limit => 8 ,:default => 99999999999999999
    add_column :social_facebook_pages, :message_since , :integer ,:limit => 8 , :default => 0
  end

  def self.down
    remove_column :social_facebook_pages, :dm_thread_time
    remove_column :social_facebook_pages, :message_since
  end
end
