class Solution::FolderMeta < ActiveRecord::Base

	self.primary_key = :id
	self.table_name = "solution_folder_meta"

	belongs_to_account

	belongs_to :solution_category_meta, :class_name => 'Solution::CategoryMeta'

	has_many :solution_folders, :class_name => "Solution::Folder", :foreign_key => "parent_id"

	has_many :customer_folders , :class_name => 'Solution::CustomerFolder' , :dependent => :destroy

	has_many :customers, :through => :customer_folders, :class_name => 'Solution::CustomerFolder'

	has_many :solution_article_meta, :class_name => "Solution::ArticleMeta"

	COMMON_ATTRIBUTES = ["visibility", "position", "is_default", "account_id"]

end