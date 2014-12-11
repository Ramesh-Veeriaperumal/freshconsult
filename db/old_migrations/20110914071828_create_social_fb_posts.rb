class CreateSocialFbPosts < ActiveRecord::Migration
  def self.up
    create_table :social_fb_posts do |t|
      t.string :post_id 
      t.integer :postable_id , :limit => 8
      t.string :postable_type
      t.integer :facebook_page_id , :limit => 8
      t.integer :account_id, :limit => 8

      t.timestamps
    end
  end

  def self.down
    drop_table :social_fb_posts
  end
end
