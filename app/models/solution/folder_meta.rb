class Solution::FolderMeta < ActiveRecord::Base

	self.primary_key = :id
  
	self.table_name = "solution_folder_meta"
  include Solution::Constants

	belongs_to_account

	belongs_to :solution_category_meta, :class_name => 'Solution::CategoryMeta'

	self.primary_key = :id

  acts_as_list :scope => :account

	belongs_to :solution_category_meta, :class_name => 'Solution::CategoryMeta', :foreign_key => "category_meta_id"

	has_many :solution_folders, :class_name => "Solution::Folder", :foreign_key => "parent_id", :autosave => true

	has_many :customer_folders , :class_name => 'Solution::CustomerFolder' , :dependent => :destroy

	has_many :customers, :through => :customer_folders, :class_name => 'Solution::CustomerFolder'

	has_many :solution_article_meta, :class_name => "Solution::ArticleMeta", :foreign_key => 'folder_meta_id'

	COMMON_ATTRIBUTES = ["visibility", "position", "is_default", "account_id"]

end
