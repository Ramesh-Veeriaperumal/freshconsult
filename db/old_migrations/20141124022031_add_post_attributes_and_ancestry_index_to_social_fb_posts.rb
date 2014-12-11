class AddPostAttributesAndAncestryIndexToSocialFbPosts < ActiveRecord::Migration 
  shard :all
  
  def self.up
    Lhm.change_table :social_fb_posts, :atomic_switch => true do |m|
      m.add_column :post_attributes,                "text"
      m.add_column :ancestry,                       "varchar(255)"
      m.add_index  ["account_id", "ancestry(30)"],  "account_ancestry_index"
      m.add_index  ["account_id", "post_id(30)"],   "index_social_fb_posts_on_post_id"
    end
  end

  def self.down
    Lhm.change_table :social_fb_posts, :atomic_switch => true do |m|
      m.remove_index  [:account_id, :ancestry], 'account_ancestry_index'
      m.remove_index  [:account_id, :post_id], 'index_social_fb_posts_on_post_id'      
      m.remove_column :post_attributes
      m.remove_column :ancestry      
    end
  end
  
end