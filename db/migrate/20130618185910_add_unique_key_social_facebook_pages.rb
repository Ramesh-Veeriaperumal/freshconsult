class AddUniqueKeySocialFacebookPages < ActiveRecord::Migration
  shard :none	
  def self.up
  	execute("ALTER TABLE social_facebook_pages ADD CONSTRAINT facebook_page_id unique(page_id)")
  end

  def self.down
  	execute("ALTER TABLE social_facebook_pages DROP INDEX facebook_page_id")
  end
end
