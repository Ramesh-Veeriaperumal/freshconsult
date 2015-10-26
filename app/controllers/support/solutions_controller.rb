class Support::SolutionsController < SupportController
	before_filter :load_category, :only => [:show]
	before_filter { |c| c.check_portal_scope :open_solutions }

  def index
    respond_to do |format|
      format.html {
        load_agent_actions(solution_categories_path, :view_solutions)
        set_portal_page :solution_home 
      }
      format.json {
        load_customer_categories
        render :json => @categories.to_json(:include=>:public_folders)
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
			@category = current_portal.solution_categories.find_by_id(params[:id])
			(raise ActiveRecord::RecordNotFound and return) if @category.nil?
		end

    def load_customer_categories
      @categories=[]
      solution_categories = @current_portal.solution_categories
      if solution_categories and solution_categories.respond_to?(:customer_categories)
        @categories = solution_categories.customer_categories.all(:include=>:public_folders)
      else
        @categories = solution_categories; # in case of portal only selected solution is available.
      end
    end
    
    def load_page_meta
      @page_meta ||= {
        :title => @category.name,
        :description => @category.description,
        :canonical => support_solution_url(@category, :host => current_portal.host)
      }
    end

    def alternate_version_languages
      return current_account.applicable_languages unless @category
      @category.solution_category_meta.solution_categories.map { |c| c.language.code}
    end
end