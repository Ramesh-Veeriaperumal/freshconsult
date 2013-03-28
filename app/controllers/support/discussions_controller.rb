class Support::DiscussionsController < SupportController
	# before_filter :scoper
	before_filter { |c| c.requires_feature :forums }
	before_filter { |c| c.check_portal_scope :open_forums }

	def index
		set_portal_page :discussions_home
	end

	def show
		# @category = current_portal.forum_categories.find_by_id(params[:id])
		set_portal_page :discussions_home
	end	

end