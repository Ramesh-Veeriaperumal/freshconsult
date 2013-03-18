class Support::SolutionsController < SupportController
	before_filter :scoper
	before_filter do |c|
		c.send(:set_portal_page, :solution_home)
	end
	before_filter { |c| c.check_portal_scope :open_solutions }
	
	def show
		# @category = @categories.find_by_id(params[:id])
		# return redirect_to support_solutions_path
	end

	private
		def scoper
			@categories = current_portal.solution_categories
		end

end