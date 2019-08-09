class AddUniqueIndexToFbPosts < ActiveRecord::Migration
  shard :all

  def self.up
    Lhm.change_table :social_fb_posts, :atomic_switch => true do |m|
      m.remove_index [:account_id, :post_id], 'index_social_fb_posts_on_post_id'
      m.add_unique_index [:account_id, :post_id], "unique_index_social_fb_posts_on_post_id"
    end
  end

  def self.down
    Lhm.change_table :social_fb_posts, :atomic_switch => true do |m|
      m.remove_index [:account_id, :post_id], 'unique_index_social_fb_posts_on_post_id'
      m.add_index  ["account_id", "post_id(30)"], "index_social_fb_posts_on_post_id"
    end
  end
end
