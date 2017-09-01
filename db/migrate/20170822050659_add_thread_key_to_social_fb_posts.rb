class AddThreadKeyToSocialFbPosts < ActiveRecord::Migration
  shard :all
  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :social_fb_posts, :atomic_switch => true do |m|
      m.add_column :thread_key, "varchar(255)"
      m.add_index [:account_id, :thread_key, :postable_type, :facebook_page_id], "index_on_thread_key"
    end
  end

  def down
    Lhm.change_table :social_fb_posts, :atomic_switch => true do |m|
      m.remove_column :thread_key
    end
  end
end
