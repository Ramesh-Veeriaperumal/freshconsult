class AddMsgTypeToSocialFbPosts < ActiveRecord::Migration
  def self.up
    add_column :social_fb_posts, :msg_type, :string ,:default => 'post'
    add_column :social_fb_posts, :thread_id, :string 
  end

  def self.down
    remove_column :social_fb_posts, :msg_type
    remove_column :social_fb_posts, :thread_id
  end
end
