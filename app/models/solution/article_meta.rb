class Solution::ArticleMeta < ActiveRecord::Base

	self.primary_key = :id
	self.table_name = "solution_article_meta"

	belongs_to_account
	has_many :solution_articles, :class_name => "Solution::Article", :foreign_key => :parent_id
	belongs_to :solution_folder_meta, :class_name => "Solution::FolderMeta"

	COMMON_ATTRIBUTES = ["account_id", "art_type", "thumbs_up", "thumbs_down", "position", "hits", 
		"created_at"]
end