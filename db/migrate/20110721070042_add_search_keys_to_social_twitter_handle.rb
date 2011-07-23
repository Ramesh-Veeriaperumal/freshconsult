class AddSearchKeysToSocialTwitterHandle < ActiveRecord::Migration
  def self.up
    add_column :social_twitter_handles, :search_keys, :text
  end

  def self.down
    remove_column :social_twitter_handles, :search_keys
  end
end
