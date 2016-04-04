class PopulateSubPortalForumCategories < ActiveRecord::Migration
  shard :all
	def self.up
	  execute(%(INSERT INTO portal_forum_categories(forum_category_id, portal_id, account_id, position) 
	  	SELECT forum_category_id, id, account_id, 1 FROM portals where main_portal = 0 AND forum_category_id IS NOT NULL ))
	end

	def self.down
	end
end
