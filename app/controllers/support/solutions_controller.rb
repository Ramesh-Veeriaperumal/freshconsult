class Support::SolutionsController < SupportController
  include Solution::PathHelper

	before_filter :load_category, :only => [:show]
	before_filter :check_version_availability, :only => [:show]
	before_filter { |c| c.check_portal_scope :open_solutions }
  before_filter :redirect_to_support_home, if: :facebook?

  def index
    respond_to do |format|
      format.html {
        load_agent_actions(agent_actions_path, :view_solutions)
        set_portal_page :solution_home 
      }
    end
  end

  def redirect_to_support_home
    redirect_to "/support/solutions/#{params[:id]}"
  end

  def show
    respond_to do |format|
      format.html {
        (render_404 && return) if @category.blank? || @category.is_default?  
        load_agent_actions(agent_actions_path(@category), :view_solutions)
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

		def unscoped_fetch
			@category = current_portal.solution_category_meta.unscoped_find(params[:id])
		end

    def default_url
      support_solution_path(@category, :url_locale => current_account.language)
    end
end
