class Solution::Category < ActiveRecord::Base

	belongs_to_account

	FEATURE_BASED_METHODS = [:folders, :public_folders, :portal_solution_categories, :portals,
    :published_articles, :articles, :user_folders, :mobihelp_app_solutions]

	has_many :folders, :class_name =>'Solution::Folder', :order => "position"

  has_many :solution_folders, :class_name =>'Solution::Folder', :order => "position"

  has_many :public_folders, 
  	:class_name =>'Solution::Folder',  
  	:order => "solution_folders.position", 
		:conditions => [" solution_folders.visibility = ? ",VISIBILITY_KEYS_BY_TOKEN[:anyone]]

  has_many :published_articles, 
    :class_name => "Solution::Article",
    :order => "solution_folders.id, solution_articles.position",
    :through => :public_folders 

  has_many :articles, :through => :folders, :order => ["solution_folders.id", "solution_articles.position"]

  has_many :portal_solution_categories, 
    :class_name => 'PortalSolutionCategory', 
    :foreign_key => :solution_category_id

  has_many :portals, 
    :through => :portal_solution_categories,
    :after_add => :clear_cache,
    :after_remove => :clear_cache

  has_many :user_folders, :class_name =>'Solution::Folder' , :order => "solution_folders.position", 
          :conditions => [" solution_folders.visibility in (?,?) ",
          VISIBILITY_KEYS_BY_TOKEN[:anyone],VISIBILITY_KEYS_BY_TOKEN[:logged_users]]

  has_many :mobihelp_app_solutions, :class_name => 'Mobihelp::AppSolution'

  has_many :mobihelp_apps, 
    :class_name => 'Mobihelp::App', 
    :through => :mobihelp_app_solutions ,
    :source => :app

  has_many :activities,
    :class_name => 'Helpdesk::Activity',
    :as => 'notable'
end