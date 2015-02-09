class PopulateMainPortalForumCategories < ActiveRecord::Migration
  shard :all
  def self.up
  	execute(%(INSERT INTO portal_forum_categories(forum_category_id, portal_id, account_id, position) 
  		SELECT forum_categories.id, portal.id, portal.account_id, forum_categories.position from forum_categories 
  		INNER JOIN portals portal on forum_categories.account_id = portal.account_id where portal.main_portal = 1))
  end

  def self.down
  end
end
