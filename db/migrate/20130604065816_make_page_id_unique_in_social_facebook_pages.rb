class MakePageIdUniqueInSocialFacebookPages < ActiveRecord::Migration
  shard :none
  def self.up
  	remove_index :social_facebook_pages, :name => "index_account_page_id"
  	add_index :social_facebook_pages, :page_id, :name => "index_page_id", :unique => true
  	add_index :social_facebook_pages, [:account_id, :page_id], :name => "index_pages_on_account_id"
  end

  def self.down
  	remove_index :social_facebook_pages, :name => "index_pages_on_account_id"
  	remove_index :social_facebook_pages, :name => "index_page_id"
  	add_index :social_facebook_pages, [:account_id, :page_id], :name => "index_account_page_id", :unique => true
  end
end
