class Solution::Folder < ActiveRecord::Base

  belongs_to :solution_folder_meta, :class_name => 'Solution::FolderMeta', :foreign_key => 'parent_id'

  has_many :solution_article_meta, :class_name => 'Solution::ArticleMeta', :through => :solution_folder_meta

  has_one :solution_category_meta, 
    :readonly => false,
    :class_name => "Solution::CategoryMeta", 
    :through => :solution_folder_meta

  has_one :category_with_meta,
    :source => :solution_categories,
		:readonly => false,
    :class_name => 'Solution::Category',
    :through => :solution_category_meta,
    :conditions => proc { "solution_categories.language_id = '#{Language.current.id}'" }
  
  has_many :articles_with_meta, 
    :class_name => 'Solution::Article', 
    :through => :solution_article_meta, 
    :source => :solution_articles,
		:readonly => false,
    :order => :"solution_article_meta.position",
    :conditions => proc { "solution_articles.language_id = '#{Language.current.id}'" },
    :extend => Solution::MultipleThroughSetters

  has_many :published_articles_with_meta, 
    :class_name => 'Solution::Article', 
    :through => :solution_article_meta, 
    :source => :solution_articles,
		:readonly => false,
    :order => :"solution_article_meta.position",
    :conditions => proc { "solution_articles.language_id = '#{Language.current.id}' and solution_articles.status = #{Solution::Article::STATUS_KEYS_BY_TOKEN[:published]}" }

  has_many :customer_folders_with_meta, 
    :class_name => 'Solution::CustomerFolder', 
    :through => :solution_folder_meta,
    :source => :customer_folders, 
    :readonly => false, 
    :dependent => :destroy,
    :extend => Solution::MultipleThroughSetters
end