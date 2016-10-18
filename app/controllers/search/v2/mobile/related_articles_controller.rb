class Search::V2::Mobile::RelatedArticlesController < Search::V2::SolutionsController
  
  before_filter :set_native_mobile, only: [:index]
  before_filter :load_ticket, only: [:index]
  
  def index
    @es_search_term = @ticket.subject
    search(esv2_agent_models)
  end
  
  private

    def process_results
      @result_set.each do |result|
        @mobile_results << result.to_mob_json['article'] if result
      end
      handle_rendering
    end
    
    def handle_rendering
      respond_to do |format|
        format.nmobile { render :json => @mobile_results }
        format.all  { render json: [], status: 403 }
      end
    end
    
    def initialize_search_parameters
      @mobile_results = []
      super
    end
    
    # @ticket used in search_solutions view
    #
    def load_ticket
      @ticket = current_account.tickets.find_by_display_id(params[:ticket])
    end
  
    # ESType - [model, associations] mapping
    # Needed for loading records from DB
    #
    def esv2_agent_models
      @@esv2_mobile_rel_soln ||= {
        'article' => { model: 'Solution::Article',  associations: [ :article_body ] }
      }
    end
end