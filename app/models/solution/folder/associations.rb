class Solution::Folder < ActiveRecord::Base

	belongs_to_account

  belongs_to :category, :class_name => 'Solution::Category'
  
  has_many :articles, :order => :position, :class_name =>'Solution::Article'

  has_many :published_articles, 
    :conditions => "solution_articles.status = #{Solution::Article::STATUS_KEYS_BY_TOKEN[:published]}",
    :order => "position",
    :class_name =>'Solution::Article'

  belongs_to :solution_folder_meta, :class_name => 'Solution::FolderMeta', :foreign_key => 'parent_id'

  has_many :solution_article_meta, :through => :solution_folder_meta, :class_name => 'Solution::ArticleMeta'

  has_one :solution_category_meta,
    :through => :solution_folder_meta,
    :class_name => "Solution::CategoryMeta",
    :readonly => false
		
  has_many :activities, :class_name => 'Helpdesk::Activity', :as => 'notable'

end