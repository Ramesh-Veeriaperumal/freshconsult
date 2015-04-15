class Solution::ArticleBody < ActiveRecord::Base

	self.table_name = "solution_article_bodies"

	belongs_to_account
	
	belongs_to :article, :class_name => "Solution::Article"

	validates_presence_of :account_id
end