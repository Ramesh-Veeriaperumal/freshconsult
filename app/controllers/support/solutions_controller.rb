class Support::SolutionsController < SupportController
	before_filter :scoper
	before_filter { |c| c.check_portal_scope :open_solutions }

	def index
		set_portal_page :solution_home
	end

	def show
		@category = @categories.find_by_id(params[:id])
		set_portal_page :solution_category
	end

	private
		def scoper
			@categories = current_portal.solution_categories
		end

end