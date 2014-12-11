class AddFbProfileIdToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :fb_profile_id, :string
  end

  def self.down
    remove_column :users, :fb_profile_id
  end
end
