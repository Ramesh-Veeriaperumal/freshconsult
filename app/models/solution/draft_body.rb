class Solution::DraftBody < ActiveRecord::Base

	self.table_name = "solution_draft_bodies"

	belongs_to_account
	belongs_to :draft, :class_name => "Solution::Draft"
  attr_accessible :description, :desc_un_html
	
	xss_sanitize :only => [:description],  :article_sanitizer => [:description]

end