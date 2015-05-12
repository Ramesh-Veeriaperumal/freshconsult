class Account < ActiveRecord::Base

  FEATURE_BASED_METHODS = [:solution_categories, :solution_articles, :solution_folders, :public_folders, 
    :published_articles]

  # Meta associations
  has_many :solution_article_meta, :class_name =>'Solution::ArticleMeta'

  has_many :solution_category_meta, 
    :class_name =>'Solution::CategoryMeta', 
    :include =>:solution_folder_meta, 
    :order => "solution_category_meta.position"

  has_many :solution_folder_meta, 
    :class_name =>'Solution::FolderMeta', 
    :through => :solution_category_meta

  # Without Meta

  has_many :portal_solution_categories, :class_name => "PortalSolutionCategory"

  has_many :solution_categories, :class_name =>'Solution::Category', :include =>:folders, :order => "solution_categories.position"

  has_many :solution_articles, :class_name =>'Solution::Article'

  has_many :solution_folders, :class_name =>'Solution::Folder', :through => :solution_categories

  has_many :public_folders, :through => :solution_categories

  has_many :published_articles, :through => :public_folders,
    :conditions => [" solution_folders.visibility = ? ", Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]]

  has_many :mobihelp_app_solutions, :class_name => 'Mobihelp::AppSolution'

  has_many :solution_customer_folders, :class_name => "Solution::CustomerFolder"

  # Through meta

	has_many :solution_categories_with_meta, 
		:class_name =>'Solution::Category', 
		:order => "solution_categories.position",
    :through => :solution_category_meta,
    :source => :solution_categories,
		:conditions => "language = '#{I18n.locale}'"

  has_many :solution_folders_with_meta, 
  	:class_name =>'Solution::Folder', 
  	:through => :solution_folder_meta,
    :source => :solution_folders,
  	:conditions => "language = '#{I18n.locale}'"

  has_many :public_folders_with_meta, :through => :solution_categories

  has_many :published_articles_with_meta, 
  	:through => :public_folders,
    :conditions => proc { [" solution_folders.visibility = ? and language = '#{I18n.locale}'", Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]]}
  
  has_many :solution_articles_with_meta, 
  	:class_name =>'Solution::Article',
    :through => :solution_article_meta,
    :source => :solution_articles,
  	:conditions => "language = '#{I18n.locale}'"

  # Alias

  alias_method :folders, :solution_folders_with_meta

  FEATURE_BASED_METHODS.each do |method|
    alias_method_chain method, :meta
  end
end