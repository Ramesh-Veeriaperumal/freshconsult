# Ticket Specific searches
#
class Search::V2::TicketsController < Search::V2::SpotlightController
  
  skip_before_filter :set_search_sort_cookie
  before_filter :initialize_search_parameters
  
  attr_accessor :search_field
  
  @@esv2_spotlight_models = {
    "ticket"  => { model: "Helpdesk::Ticket",   associations: [ :requester, :ticket_states, { :flexifield => :flexifield_def }] }
  }
  
  def index
    case @search_field
    when 'display_id'
      @search_context = :merge_display_id
    when 'subject'
      @search_context = :merge_subject
    when 'requester'
      @search_context = :merge_requester
    end
    
    search
  end
  
  private
  
    def construct_es_params
      Hash.new.tap do |es_params|
        es_params[:account_id]  = current_account.id
        
        if @search_field == 'requester'
          es_params[:requester_ids] = @requester_ids
        else
          es_params[:search_term] = @search_key
        end
        
        es_params[:size]  = @size
        es_params[:from]  = @offset

        es_params[:sort_by]         = @search_sort
        es_params[:sort_direction]  = @sort_direction
      end
    end
    
    def handle_rendering
      respond_to do |format|
				format.json { render :json => @result_json }
			end
    end
    
    # Workaround for fetching users from ES
    # Seperate as no need to load from DB
    #
    def search_users
      begin
        es_results      = Search::V2::SearchRequestHandler.new(current_account.id,
                                                                :requester_autocomplete,
                                                                ['user']
                                                              ).fetch(search_term: SearchUtil.es_filter_exact(@search_key),
                                                                      sort_by: '_score',
                                                                      sort_direction: 'desc'
                                                                )
        @requester_ids  = es_results['hits']['hits'].collect { |doc| doc['_id'].to_i }
      rescue => e
        NewRelic::Agent.notice_error(e)
        @requester_ids  = []
      end
    end
  
    def initialize_search_parameters
      super
      @searchable_klasses = ['Helpdesk::Ticket']
      @search_field       = params[:search_field]
      @size               = Search::Utils::MAX_PER_PAGE
      @offset             = 0
      @search_by_field    = true
      
      if (@search_field == 'display_id')
        @search_sort      = 'display_id'
        @sort_direction   = 'asc'
      else
        @search_sort      = 'created_at'
        @sort_direction   = 'desc'
      end
      search_users if (@search_field == 'requester')
    end
end