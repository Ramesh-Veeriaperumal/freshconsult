class PopulateMainPortalSolutionCategories < ActiveRecord::Migration
  shard :all
  def self.up
  	execute(%(INSERT INTO portal_solution_categories(solution_category_id, portal_id, account_id, position) 
  		SELECT solution_categories.id, portal.id, portal.account_id, solution_categories.position from solution_categories 
  		INNER JOIN portals portal on solution_categories.account_id = portal.account_id where portal.main_portal = 1))
  end

  def self.down
  end
end
