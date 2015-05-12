class Solution::ArticleMeta < ActiveRecord::Base

	self.primary_key = :id

	belongs_to_account

	self.table_name = "solution_article_meta"

	self.primary_key = :id

	acts_as_list :scope => :account

	has_many :solution_articles, :class_name => "Solution::Article", :foreign_key => :parent_id, :autosave => true

	belongs_to :solution_folder_meta, :class_name => "Solution::FolderMeta", :foreign_key => :folder_meta_id
	
	has_one :solution_folder, :class_name => "Solution::Folder", :through => :solution_folder_meta

	COMMON_ATTRIBUTES = ["account_id", "art_type", "thumbs_up", "thumbs_down", "position", "hits"]
 
	def article_for_language(language)
		solution_articles.for_language(language).first
	end
end