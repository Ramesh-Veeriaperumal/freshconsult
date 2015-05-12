class Solution::Folder < ActiveRecord::Base

  belongs_to :solution_folder_meta, :class_name => 'Solution::FolderMeta', :foreign_key => 'parent_id'

  has_many :solution_article_meta, :class_name => 'Solution::ArticleMeta', :through => :solution_folder_meta

  has_one :solution_category_meta, 
    :class_name => "Solution::CategoryMeta", 
    :through => :solution_folder_meta

  has_one :category_with_meta,
    :source => :solution_categories,
    :class_name => 'Solution::Category',
    :through => :solution_category_meta,
    :conditions => "language = '#{I18n.locale}'"
  
  has_many :articles_with_meta, 
    :class_name => 'Solution::Article', 
    :through => :solution_article_meta, 
    :source => :solution_articles,
    :conditions => "language = '#{I18n.locale}'"

  has_many :published_articles_with_meta, 
    :class_name => 'Solution::Article', 
    :through => :solution_article_meta, 
    :source => :solution_articles,
    :conditions => "language = '#{I18n.locale}' and solution_articles.status = #{Solution::Article::STATUS_KEYS_BY_TOKEN[:published]}"

  FEATURE_BASED_METHODS.each do |method|
    alias_method_chain method, :meta
  end

end