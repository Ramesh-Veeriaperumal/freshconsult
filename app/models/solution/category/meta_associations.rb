class Solution::Category < ActiveRecord::Base

	belongs_to :solution_category_meta, :class_name => 'Solution::CategoryMeta', :foreign_key => "parent_id"

  has_many :solution_folder_meta, :class_name => 'Solution::FolderMeta', :through => :solution_category_meta

	has_many :folders_with_meta, 
		:class_name =>'Solution::Folder' ,
		:through => :solution_folder_meta,
		:source => :solution_folders,
		:dependent => :destroy, 
		:order => "position",
    :conditions => "solution_folders.language = '#{I18n.locale}'"

  has_many :public_folders_with_meta, 
  	:class_name =>'Solution::Folder' ,  
  	:through => :solution_folder_meta,
		:source => :solution_folders,
		:order => "position",
    :conditions => ["solution_folders.language = '#{I18n.locale}' and solution_folders.visibility = ? ",VISIBILITY_KEYS_BY_TOKEN[:anyone]]

  has_many :portal_solution_categories_with_meta, 
    :class_name => 'PortalSolutionCategory',
    :through => :solution_category_meta,
    :source => :portal_solution_categories,
    :foreign_key => :solution_category_id, 
    :dependent => :delete_all

  has_many :published_articles_with_meta, :through => :public_folders_with_meta

  has_many :articles_with_meta, :through => :folders_with_meta

  has_many :portals_with_meta, :through => :portal_solution_categories_with_meta, :source => :portal

  has_many :user_folders_with_meta,
    :class_name =>'Solution::Folder',
    :through => :solution_folder_meta,
    :source => :solution_folders,
    :order => "position", 
    :conditions => [" solution_folders.visibility in (?,?) ",
          VISIBILITY_KEYS_BY_TOKEN[:anyone],VISIBILITY_KEYS_BY_TOKEN[:logged_users]]

  has_many :mobihelp_app_solutions_with_meta, 
    :class_name => 'Mobihelp::AppSolution',
    :through => :solution_category_meta,
    :dependent => :destroy

  has_many :mobihelp_apps_with_meta,
    :class_name => 'Mobihelp::App', 
    :through => :mobihelp_app_solutions_with_meta

  alias_method :solution_folders, :folders_with_meta

  FEATURE_BASED_METHODS.each do |method|
  	alias_method_chain method, :meta
  end

end