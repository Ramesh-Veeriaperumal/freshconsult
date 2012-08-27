class Support::SolutionsController < SupportController
	before_filter :scoper
	before_filter do |c|
		c.send(:set_portal_page, :solution_home)
	end

	def show
		@category = @categories.find_by_id(params[:id])
	end

	private
		def scoper
			@categories = current_portal.solution_categories
		end

end