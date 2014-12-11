class CreateSocialFacebookPages < ActiveRecord::Migration
  def self.up
    create_table :social_facebook_pages do |t|
      t.integer :profile_id , :limit => 8
      t.string  :access_token
      t.integer :page_id , :limit => 8
      t.string  :page_name
      t.string  :page_token
      t.string  :page_img_url
      t.string  :page_link
      t.boolean :import_visitor_posts , :default => true
      t.boolean :import_company_posts , :default => false
      t.boolean :enable_page , :default => false
      t.integer :fetch_since , :limit => 8
      t.integer :product_id , :limit => 8
      t.integer :account_id , :limit => 8

      t.timestamps
    end
    
    add_index :social_facebook_pages, [:account_id,:page_id], 
          :name => "index_account_page_id", :unique => true
    
    add_index :social_facebook_pages, :product_id, 
          :name => "index_product_id"
          
  end

  def self.down
    drop_table :social_facebook_pages
  end
end
