class Solution::DraftBody < ActiveRecord::Base

	self.table_name = "solution_draft_bodies"

	belongs_to :account
	belongs_to :draft, :class_name => "Solution::Draft"
	
	xss_sanitize :only => [:description],  :article_sanitizer => [:description]

end