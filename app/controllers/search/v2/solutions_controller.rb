# Article Specific searches
#
class Search::V2::SolutionsController < Search::V2::SpotlightController
  
  skip_before_filter :set_search_sort_cookie
  before_filter :initialize_search_parameters
  before_filter :load_ticket, :only => [:related_solutions, :search_solutions]
  
  attr_accessor :search_key, :ticket, :suggest
  
  # ESType - [model, associations] mapping
  # Needed for loading records from DB
  #
  @@esv2_spotlight_models = {
    'article' => { model: 'Solution::Article',  associations: [ :folder, :article_body ] }
  }
    
  # Find solutions for ticket
  #
  def related_solutions
    @search_key = @ticket.subject
    search

    respond_to do |format|
      format.html do
        render template: 'search/solutions/related_solutions', :layout => false
      end
			format.js do
				render template: 'search/solutions/related_solutions', :layout => false
			end
    end
  end

  # Find solutions for insert_solution search
  # _Note_: Need to check if can be handled with related_solutions
  #
  def search_solutions
    search
    render template: 'search/solutions/search_solutions', :layout => false
  end
  
  private
    
    # Keep it dummy to prevent rendering
    # Rendering handled in action
    #
    def handle_rendering
    end
  
    def initialize_search_parameters
      super
      @search_key         = params[:q] || ''
      @suggest            = true
      @searchable_klasses = ['Solution::Article']
    end
    
    # @ticket used in search_solutions view
    #
    def load_ticket
      @ticket = current_account.tickets.find_by_id(params[:ticket])
    end
end