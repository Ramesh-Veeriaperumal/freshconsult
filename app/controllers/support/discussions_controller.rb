class Support::DiscussionsController < SupportController
	before_filter :scoper

	def index
		set_portal_page :discussions_home
	end

	def show
		@category = scoper.find_by_id(params[:id])
		set_portal_page :discussions_home
	end	

	private

		def scoper
			@categories = current_portal.forum_categories
		end

end