class Solution::Folder < ActiveRecord::Base

	belongs_to_account

  belongs_to :category, :class_name => 'Solution::Category'
  
  has_many :articles, :class_name =>'Solution::Article', :order => :position

  has_many :published_articles, :class_name =>'Solution::Article', :order => "position",
           :conditions => "solution_articles.status = #{Solution::Article::STATUS_KEYS_BY_TOKEN[:published]}"

  has_many :customer_folders , :class_name => 'Solution::CustomerFolder'

  belongs_to :solution_folder_meta, :class_name => 'Solution::FolderMeta', :foreign_key => 'parent_id'

  has_many :solution_article_meta, :class_name => 'Solution::ArticleMeta', :through => :solution_folder_meta

  has_one :solution_category_meta, 
    :readonly => false,
    :class_name => "Solution::CategoryMeta", 
    :through => :solution_folder_meta
		
  has_many :activities, :class_name => 'Helpdesk::Activity', :as => 'notable'

end