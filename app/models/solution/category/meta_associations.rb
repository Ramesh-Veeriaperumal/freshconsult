class Solution::Category < ActiveRecord::Base

	belongs_to :solution_category_meta, :class_name => 'Solution::CategoryMeta', :foreign_key => "parent_id"

  has_many :solution_folder_meta, :class_name => 'Solution::FolderMeta', :through => :solution_category_meta, :foreign_key => :solution_category_meta_id

	has_many :folders_with_meta, 
		:class_name =>'Solution::Folder' ,
		:through => :solution_folder_meta,
		:source => :solution_folders,
		:dependent => :destroy, 
		:order => "position",
		:readonly => false,
  	:order => :"solution_folder_meta.position",
		:conditions => proc { "solution_folders.language_id = '#{Language.current.id}'" },
		:extend => Solution::MultipleThroughSetters

  has_many :public_folders_with_meta, 
  	:class_name =>'Solution::Folder' ,  
  	:through => :solution_folder_meta,
		:source => :solution_folders,
    :order => :"solution_folder_meta.position",
		:readonly => false,
    :conditions => proc { ["solution_folders.language_id = '#{Language.current.id}' and solution_folder_meta.visibility = ? ",VISIBILITY_KEYS_BY_TOKEN[:anyone]] }

  has_many :portal_solution_categories_with_meta, 
    :class_name => 'PortalSolutionCategory',
    :through => :solution_category_meta,
    :source => :portal_solution_categories,
    :foreign_key => :solution_category_id, 
		:readonly => false,
    :dependent => :delete_all

  has_many :published_articles_with_meta, 
    :through => :public_folders_with_meta,
    :order => ["solution_folder_meta.id", "solution_article_meta.position"]

  has_many :articles_with_meta, 
    :through => :folders_with_meta,
    :order => ["solution_folder_meta.id", "solution_article_meta.position"]

  has_many :portals_with_meta, :through => :portal_solution_categories_with_meta, :source => :portal

  has_many :user_folders_with_meta,
    :class_name =>'Solution::Folder',
    :through => :solution_folder_meta,
    :source => :solution_folders,
    :order => :"solution_folder_meta.position",
		:readonly => false,
    :conditions => [" solution_folders.visibility in (?,?) ",
          VISIBILITY_KEYS_BY_TOKEN[:anyone],VISIBILITY_KEYS_BY_TOKEN[:logged_users]]

  has_many :mobihelp_app_solutions_with_meta, 
    :class_name => 'Mobihelp::AppSolution',
    :through => :solution_category_meta,
    :source => :mobihelp_app_solutions,
		:readonly => false,
    :dependent => :destroy

  has_many :mobihelp_apps_with_meta,
		:readonly => false,
    :class_name => 'Mobihelp::App', 
    :through => :mobihelp_app_solutions_with_meta

  alias_method :solution_folders, :folders_with_meta
end