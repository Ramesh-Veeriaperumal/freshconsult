# Agent side spotlight search
#
class Search::V2::SpotlightController < ApplicationController

  include Search::SearchResultJson
  include Search::V2::AbstractController
  helper Search::SearchHelper
  
  before_filter :set_search_sort_cookie

  # Unscoped spotlight search
  #
  def all
    @search_context = :agent_spotlight_global
    @klasses        = esv2_klasses
    # Store in recent searches
    Search::RecentSearches.new(@search_key).store if !@search_key.blank? and User.current.present?
    search(esv2_agent_models)
  end

  # Tickets scoped spotlight search
  #
  def tickets
    @search_context = :agent_spotlight_ticket
    @klasses        = ['Helpdesk::Ticket', 'Helpdesk::ArchiveTicket']
    search(esv2_agent_models)
  end

  # Customers scoped spotlight search
  #
  def customers
    redirect_user unless privilege?(:view_contacts)

    @search_context = :agent_spotlight_customer
    @klasses        = ['User', 'company']
    search(esv2_agent_models)
  end

  # Forums scoped spotlight search
  #
  def forums
    redirect_user unless privilege?(:view_forums)

    @search_context = :agent_spotlight_topic
    @klasses        = ['Topic']
    search(esv2_agent_models)
  end

  # Solutions scoped spotlight search
  #
  def solutions
    redirect_user unless privilege?(:view_solutions)

    @search_context = :agent_spotlight_solution
    @klasses        = ['Solution::Article']
    search(esv2_agent_models)
  end

  private

    def esv2_klasses
      super.tap do |model_names|
        model_names.concat(['Helpdesk::Ticket', 'Helpdesk::ArchiveTicket'])

        model_names.concat(['User', 'Company']) if privilege?(:view_contacts)
        model_names.push('Topic')               if privilege?(:view_forums)
        model_names.push('Solution::Article')   if privilege?(:view_solutions)
      end
    end
    
    # => Defaults <=
    # ticket.deleted: false
    # ticket.spam: false
    # user.helpdesk_agent: false
    # user.deleted: false
    #
    def construct_es_params
      super.tap do |es_params|
        if current_user.restricted?
          es_params[:restricted_responder_id] = current_user.id.to_i
          es_params[:restricted_group_id]     = current_user.agent_groups.map(&:group_id) if current_user.group_ticket_permission
        end
        
        if searchable_klasses.include?('Solution::Article')
          # Params considered in 'ALL' search for this model
          #
          es_params[:language_id] = Language.for_current_account.id

          # Params only if solution-scoped.
          #
          if (@search_context == :agent_spotlight_solution)
            es_params[:article_category_id] = params[:category_id].to_i if params[:category_id].present?
            es_params[:article_folder_id]   = params[:folder_id].to_i if params[:folder_id].present?
            es_params[:language_id] = params[:language_id] if params[:language_id].present?
          end
        end

        if searchable_klasses.include?('Topic')
          # Params considered in 'ALL' search for this model
          #
          #=> All search params

          # Params only if topic-scoped.
          #
          if (@search_context == :agent_spotlight_topic)
            es_params[:topic_category_id]   = params[:category_id].to_i if params[:category_id].present?
          end
        end
        
        unless (@search_sort.to_s == 'relevance') or @suggest
          es_params[:sort_by]         = @search_sort
          es_params[:sort_direction]  = @sort_direction
        end
        
        es_params[:size]  = @size
        es_params[:from]  = @offset
      end.merge(ES_V2_BOOST_VALUES[@search_context])
    end

    def process_results
      @result_set.each do |result|
        @result_json[:results] << send(%{#{result.class.model_name.singular}_json}, result) if result
      end

      @result_json[:current_page] = @current_page
      @total_pages                = (@es_results['hits']['total'].to_f / @size).ceil
      @search_results             = (@search_results.presence || []) + @result_set

      super
    end

    def handle_rendering
      @result_json = @result_json.to_json
      respond_to do |format|
        format.html do 
          if request.xhr? and !request.headers['X-PJAX']
            render :partial => '/search/result'
          else
            render 'search/index'
          end
        end
        format.js do 
          render :partial => 'search/search_sort'
        end
        format.json do
          render :json => @result_json
        end
      end
    end
    
    def redirect_user
      redirect_to search_v2_spotlight_index_path
    end

    ######################
    ### Before filters ###
    ######################

    def initialize_search_parameters
      super
      @search_sort    = params[:search_sort] || cookies[:search_sort]
      @sort_direction = 'desc'
      @size           = Search::Utils::MAX_PER_PAGE #=> Overriding just to be safe.
      @result_json    = { :results => [], :current_page => @current_page }
    end

    def set_search_sort_cookie
      cookies[:search_sort] = @search_sort
    end

    # ESType - [model, associations] mapping
    # Needed for loading records from DB
    #
    def esv2_agent_models
      @@esv2_agent_spotlight ||= {
        'company'       => { model: 'Company',            associations: [] }, 
        'topic'         => { model: 'Topic',              associations: [ { forum: :forum_category }, :user ] }, 
        'ticket'        => { model: 'Helpdesk::Ticket',   associations: [ { flexifield: :flexifield_def }, { requester: :avatar }, :ticket_states, :ticket_old_body, :ticket_status, :responder, :group, { :ticket_states => :tickets } ] },
        'archiveticket' => { model: 'Helpdesk::ArchiveTicket',     associations: [] }, 
        'article'       => { model: 'Solution::Article',  associations: [ :user, :article_body, :recent_author, { :solution_folder_meta => :en_folder } ] }, 
        'user'          => { model: 'User',               associations: [ :avatar, :customer, :default_user_company, :companies ] }
      }
    end
end