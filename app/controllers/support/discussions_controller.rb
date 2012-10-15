class Support::DiscussionsController < SupportController
	before_filter :scoper
	before_filter :set_selected_tab

	before_filter do |c|
		c.send(:set_portal_page, :discussions_home)
	end

	def index
		@current_tab = "home"		
	end

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