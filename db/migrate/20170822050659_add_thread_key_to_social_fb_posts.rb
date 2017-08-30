class AddThreadKeyToSocialFbPosts < ActiveRecord::Migration
  shard :all
  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :social_fb_posts, :atomic_switch => true do |m|
      m.add_column :thread_key, "varchar(255)"
      m.add_index [:account_id, :thread_key, :postable_type, :facebook_page_id], "index_social_fb_posts_on_account_id_thread_key_and_postable_type_and_facebook_page_id"
    end
  end

  def down
    Lhm.change_table :social_fb_posts, :atomic_switch => true do |m|
      m.remove_column :thread_key
      m.remove_index [:account_id, :thread_key, :postable_type, :facebook_page_id], "index_social_fb_posts_on_account_id_thread_key_and_postable_type_and_facebook_page_id"
    end
  end
end
