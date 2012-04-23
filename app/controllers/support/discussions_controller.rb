class Support::DiscussionsController < Support::SupportController
	before_filter :scoper

	def show
		@category = scoper.find_by_id(params[:id])
	end	

private
	def scoper
		@categories = current_portal.forum_categories
	end
end