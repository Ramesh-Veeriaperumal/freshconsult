class Account < ActiveRecord::Base

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

  has_many :solution_folders, :class_name =>'Solution::Folder', :order => "solution_folders.parent_id"

  has_many :public_folders, :through => :solution_categories, :order => "solution_folders.category_id, solution_folders.position"

  has_many :published_articles, :through => :public_folders,
    :conditions => [" solution_folders.visibility = ? ", Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]],
    :order => ["solution_folders.id", "solution_articles.position"]

  has_many :mobihelp_app_solutions, :class_name => 'Mobihelp::AppSolution'

  has_many :solution_customer_folders, :class_name => "Solution::CustomerFolder"
    
  has_many :solution_article_bodies, :class_name =>'Solution::ArticleBody'

  # Alias

  alias_method :folders, :solution_folders

end