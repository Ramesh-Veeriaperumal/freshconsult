class Solution::ArticleMeta < ActiveRecord::Base

	self.primary_key = :id
	belongs_to_account
	self.table_name = "solution_article_meta"
	
	include Redis::RedisKeys
	include Redis::OthersRedis
	include Community::HitMethods
	
	include Solution::LanguageAssociations

	delegate :draft, :status, :user, :to => :primary_article

	has_many :solution_articles, :class_name => "Solution::Article", :foreign_key => :parent_id, :autosave => true

	belongs_to :solution_folder_meta, 
		:class_name => "Solution::FolderMeta", 
		:foreign_key => :solution_folder_meta_id

	has_one :solution_category_meta,
		:class_name => "Solution::CategoryMeta",
		:through => :solution_folder_meta
			
	has_one :solution_folder, :class_name => "Solution::Folder", :through => :solution_folder_meta

	COMMON_ATTRIBUTES = ["art_type", "position", "created_at"]
	
	HITS_CACHE_THRESHOLD = 100

	def hit_key
		SOLUTION_META_HIT_TRACKER % {:account_id => account_id, :article_meta_id => id }
	end
end