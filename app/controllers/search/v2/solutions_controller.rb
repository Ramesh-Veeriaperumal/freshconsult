# Article Specific searches
#
class Search::V2::SolutionsController < Search::V2::SpotlightController
  
  skip_before_filter :set_search_sort_cookie
  before_filter :load_ticket, :only => [:related_solutions, :search_solutions]
  
  attr_accessor :ticket, :suggest
    
  # Find solutions for ticket
  #
  def related_solutions
    @es_search_term = @ticket.subject
    search
    render template: 'search/solutions/related_solutions', :layout => false
  end

  # Find solutions for insert_solution search
  # _Note_: Need to check if can be handled with related_solutions
  #
  def search_solutions
    search
    render template: 'search/solutions/search_solutions', :layout => false
  end
  
  private
  
    def initialize_search_parameters
      super
      @search_context     = :agent_spotlight_solution
      @suggest            = true
      @no_render          = true
      @searchable_klasses = ['Solution::Article']
    end
    
    # @ticket used in search_solutions view
    #
    def load_ticket
      @ticket = current_account.tickets.find_by_id(params[:ticket])
    end
  
    # ESType - [model, associations] mapping
    # Needed for loading records from DB
    #
    def esv2_agent_models
      @@esv2_agent_solution ||= {
        'article' => { model: 'Solution::Article',  associations: [ :folder, :article_body ] }
      }
    end
end