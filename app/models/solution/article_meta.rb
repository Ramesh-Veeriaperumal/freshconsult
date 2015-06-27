class Solution::ArticleMeta < ActiveRecord::Base

	self.primary_key = :id
	self.table_name = "solution_article_meta"

	include Redis::RedisKeys
	include Redis::OthersRedis
	include Community::HitMethods

	belongs_to_account
	has_many :solution_articles, :class_name => "Solution::Article", :foreign_key => :parent_id
	belongs_to :solution_folder_meta, :class_name => "Solution::FolderMeta"

	HITS_CACHE_THRESHOLD = 100

	COMMON_ATTRIBUTES = ["account_id", "art_type", "position", "created_at"]

	def hit_key
		SOLUTION_META_HIT_TRACKER % {:account_id => account_id, :article_meta_id => id }
	end
end