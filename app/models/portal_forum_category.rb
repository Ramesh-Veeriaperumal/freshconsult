class PortalForumCategory < ActiveRecord::Base

	belongs_to_account
	belongs_to :portal
	belongs_to :forum_category, :class_name => 'ForumCategory'

	acts_as_list :scope => :portal
end