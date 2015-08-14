class Solution::FolderMeta < ActiveRecord::Base

	self.primary_key = :id
  
	self.table_name = "solution_folder_meta"
  include Solution::Constants
	belongs_to_account

	belongs_to :solution_category_meta, :class_name => 'Solution::CategoryMeta'

	has_many :solution_folders, :class_name => "Solution::Folder", :foreign_key => "parent_id", :autosave => true

	has_many :customer_folders , :class_name => 'Solution::CustomerFolder' , :dependent => :destroy

	has_many :customers, :through => :customer_folders, :class_name => 'Solution::CustomerFolder'

	has_many :solution_article_meta, :class_name => "Solution::ArticleMeta", :foreign_key => :solution_folder_meta_id, :order => :position

	has_many :solution_articles, 
		:class_name => "Solution::Article", 
		:through => :solution_article_meta,
		:order => :"solution_article_meta.position"

	COMMON_ATTRIBUTES = ["visibility", "position", "is_default", "created_at"]

end
