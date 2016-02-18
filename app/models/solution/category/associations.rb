class Solution::Category < ActiveRecord::Base

	belongs_to_account

	FEATURE_BASED_METHODS = [:folders, :public_folders, :portal_solution_categories, :portals,
    :published_articles, :articles, :user_folders, :mobihelp_app_solutions]

	has_many :folders, :order => "position", :class_name =>'Solution::Folder'

  has_many :solution_folders, :order => "position", :class_name =>'Solution::Folder'

  has_many :public_folders, 
    :conditions => [" solution_folders.visibility = ? ",VISIBILITY_KEYS_BY_TOKEN[:anyone]],
    :order => "solution_folders.position",
  	:class_name =>'Solution::Folder'
		

  has_many :published_articles,
    :through => :public_folders,
    :order => "solution_folders.id, solution_articles.position",
    :class_name => "Solution::Article"

  has_many :articles, 
    :through => :folders, 
    :order => ["solution_folders.id", "solution_articles.position"]

  has_many :portal_solution_categories, 
    :class_name => 'PortalSolutionCategory', 
    :foreign_key => :solution_category_id

  has_many :portals, 
    :through => :portal_solution_categories,
    :after_add => :clear_cache,
    :after_remove => :clear_cache

  has_many :user_folders,
    :conditions => [" solution_folders.visibility in (?,?) ", VISIBILITY_KEYS_BY_TOKEN[:anyone],VISIBILITY_KEYS_BY_TOKEN[:logged_users]],
    :order => "solution_folders.position",
    :class_name =>'Solution::Folder'
    

  has_many :mobihelp_app_solutions, :class_name => 'Mobihelp::AppSolution'

  has_many :mobihelp_apps, 
    :through => :mobihelp_app_solutions,
    :source => :app,
    :class_name => 'Mobihelp::App'

	belongs_to :solution_category_meta, 
    :class_name => 'Solution::CategoryMeta', 
    :foreign_key => "parent_id"

  has_many :solution_folder_meta,
    :through => :solution_category_meta,
    :class_name => 'Solution::FolderMeta',
    :foreign_key => :solution_category_meta_id

  has_many :activities,
    :class_name => 'Helpdesk::Activity',
    :as => 'notable'
end