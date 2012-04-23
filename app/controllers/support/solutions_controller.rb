class Support::SolutionsController < Support::SupportController
	before_filter :scoper

	def show
		@category = @categories.find_by_id(params[:id])
	end

	private
	def scoper
		@categories = current_portal.solution_categories
	end
end