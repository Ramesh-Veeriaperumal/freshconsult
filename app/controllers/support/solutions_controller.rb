class Support::SolutionsController < SupportController
	before_filter :load_category, :only => [:show]
	before_filter :check_version_availability, :only => [:show]
	before_filter { |c| c.check_portal_scope :open_solutions }

  def index
    respond_to do |format|
      format.html {
        load_agent_actions(solution_categories_path, :view_solutions)
        set_portal_page :solution_home 
      }
    end
  end

  def show
    respond_to do |format|
      format.html {
        (render_404 and return) if @category.is_default?        
        load_agent_actions(solution_category_path(@category), :view_solutions)
        load_page_meta
        set_portal_page :solution_category 
      }
    end
  end

	private
		
		def load_category
			#TO BE CHECKED MULTILINGUAL - check why reorder('') was added 
      @solution_item = @category = current_portal.solution_category_meta.reorder('').find_by_id(params[:id])
    end
    
    def load_page_meta
      @page_meta ||= {
        :title => @category.name,
        :description => @category.description,
        :canonical => support_solution_url(@category, :host => current_portal.host)
      }
    end

    def alternate_version_languages
      return current_account.all_portal_languages unless @category
      @category.solution_categories.map { |c| c.language.code}
    end

		def unscoped_fetch
			@category = current_portal.solution_category_meta.unscoped_find(params[:id])
		end

    def default_url
      support_solution_path(@category, :url_locale => current_account.language)
    end
end
