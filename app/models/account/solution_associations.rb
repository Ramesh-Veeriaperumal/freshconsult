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

  has_many :solution_categories, :class_name =>'Solution::Category', :order => "solution_categories.position"

  has_many :solution_articles, :class_name =>'Solution::Article'

  has_many :solution_folders, :class_name =>'Solution::Folder', :order => "solution_folders.parent_id"

  has_many :mobihelp_app_solutions, :class_name => 'Mobihelp::AppSolution'

  has_many :solution_customer_folders, :class_name => "Solution::CustomerFolder"
    
  has_many :solution_article_bodies, :class_name =>'Solution::ArticleBody'

  has_many :public_category_meta,
    class_name: 'Solution::CategoryMeta',
    conditions: { is_default: false }

  has_many :public_folder_meta,
    class_name: 'Solution::FolderMeta',
    through: :public_category_meta

  has_many :published_article_meta,
    class_name: 'Solution::ArticleMeta',
    through: :public_folder_meta

  has_many :solution_article_versions, # rubocop:disable HasManyOrHasOneDependent,InverseOf
           class_name: 'Solution::ArticleVersion'

  has_many :helpdesk_approvals,
           class_name: 'Helpdesk::Approval',
           inverse_of: :approvable

  has_many :helpdesk_approver_mappings,
           class_name: 'Helpdesk::ApproverMapping',
           inverse_of: :accounts

  # Alias

  alias_method :folders, :solution_folders

end