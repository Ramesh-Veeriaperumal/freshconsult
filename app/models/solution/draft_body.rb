class Solution::DraftBody < ActiveRecord::Base

	set_table_name "solution_draft_bodies"

	belongs_to :account
	belongs_to :draft, :class_name => "Solution::Draft"

	serialize :seo_data
end