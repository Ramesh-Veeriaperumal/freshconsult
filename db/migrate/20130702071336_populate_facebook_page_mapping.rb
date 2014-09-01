class PopulateFacebookPageMapping < ActiveRecord::Migration
	shard :none
  def self.up
  	execute("INSERT INTO facebook_page_mappings (facebook_page_id, account_id) SELECT page_id, account_id FROM social_facebook_pages")
  end

  def self.down
  	execute("DELETE FROM facebook_page_mappings")
  end
end
