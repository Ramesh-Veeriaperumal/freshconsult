# Ticket Specific searches
#
class Search::V2::TicketsController < ApplicationController
  
  include Search::SearchResultJson
  include Search::V2::AbstractController
  
  def index
    search_users if (@search_field == 'requester')

    @search_context = case @search_field
      when 'display_id'
        :merge_display_id
      when 'subject'
        :merge_subject
      when 'requester'
        :merge_requester
    end
    
    search(esv2_agent_models)
  end
  
  private
  
    def construct_es_params
      super.tap do |es_params|
        es_params[:requester_ids] = @requester_ids if @search_field == 'requester'

        if current_user.restricted?
          es_params[:restricted_responder_id] = current_user.id.to_i
          es_params[:restricted_group_id]     = current_user.agent_groups.map(&:group_id) if current_user.group_ticket_permission
        end
        
        es_params[:size]            = @size
        es_params[:sort_by]         = @search_sort
        es_params[:sort_direction]  = @sort_direction
      end
    end

    def process_results
      @result_set.each do |result|
        @result_json[:results] << send(%{#{result.class.model_name.singular}_json}, result) if result
      end
      super
    end
    
    def handle_rendering
      respond_to do |format|
        format.json { render :json => @result_json.to_json }
      end
    end
    
    # Workaround for fetching users from ES
    # Seperate as no need to load from DB
    #
    def search_users
      begin
        user_params = Hash.new.tap do |es_params|
          es_params[:search_term]     = @es_search_term
          es_params[:request_id]      = request.uuid
          es_params[:sort_by]         = '_score'
          es_params[:sort_direction]  = 'desc'
        end

        es_results  = Search::V2::SearchRequestHandler.new(current_account.id,
                                                                Search::Utils.template_context(:requester_autocomplete, @exact_match),
                                                                ['user']
                                                              ).fetch(user_params.merge(ES_V2_BOOST_VALUES[:requester_autocomplete])
                                                                )
        @requester_ids  = es_results['hits']['hits'].collect { |doc| doc['_id'].to_i }
      rescue => e
        Rails.logger.error "Searchv2 exception - #{e.message} - #{e.backtrace.first}"
        NewRelic::Agent.notice_error(e)
        @requester_ids  = []
      end
    end
  
    def initialize_search_parameters
      super
      @klasses            = ['Helpdesk::Ticket']
      @result_json        = { :results => [], :current_page => @current_page }
      @search_field       = params[:search_field]
      @search_by_field    = true #=> Used in search_result_json.
      
      if (@search_field == 'display_id')
        @search_sort      = 'display_id'
        @sort_direction   = 'asc'
      else
        @search_sort      = 'created_at'
        @sort_direction   = 'desc'
      end
    end
  
    # ESType - [model, associations] mapping
    # Needed for loading records from DB
    #
    def esv2_agent_models
      @@esv2_agent_ticket ||= {
        'ticket'  => { model: 'Helpdesk::Ticket', associations: [ :requester, :account, :schema_less_ticket ] }
      }
    end
end