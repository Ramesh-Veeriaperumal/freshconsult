class Support::DiscussionsController < SupportController
	before_filter :scoper
	before_filter :set_selected_tab

	def show
		@category = scoper.find_by_id(params[:id])
	end	

	private

		def scoper
			@categories = current_portal.forum_categories
		end

		def set_selected_tab
			@selected_tab = :forums
		end
end