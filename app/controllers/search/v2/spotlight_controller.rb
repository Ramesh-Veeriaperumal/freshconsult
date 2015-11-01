# Agent side spotlight search
#
class Search::V2::SpotlightController < ApplicationController

  include Search::SearchResultJson
  helper Search::SearchHelper
  
  before_filter :set_search_sort_cookie, :initialize_search_parameters

  attr_accessor :search_key, :search_sort, :result_json, :es_results, :search_results, :total_pages, :current_page

  @@esv2_spotlight_models = {
    "company" => { model: "Company",            associations: [] }, 
    "topic"   => { model: "Topic",              associations: [{ forum: :forum_category }, :user ] }, 
    "ticket"  => { model: "Helpdesk::Ticket",   associations: [{ flexifield: :flexifield_def },{ requester: :avatar }, :ticket_states, :ticket_old_body, :ticket_status, :responder, :group ] }, 
    "note"    => { model: "Helpdesk::Note",     associations: [ :note_old_body,{ notable: [ :ticket_status, :ticket_states, :responder, :group,{ requester: :avatar }]}] }, 
    "article" => { model: "Solution::Article",  associations: [ :user, :folder ] }, 
    "user"    => { model: "User",               associations: [ :avatar, :customer ] }
  }

  # Unscoped spotlight search
  #
  def all
    @@searchable_klasses = esv2_klasses
    search
  end

  # Tickets scoped spotlight search
  #
  def tickets
    @@searchable_klasses = ['Helpdesk::Ticket', 'Helpdesk::Note']
    search
  end

  # Customers scoped spotlight search
  #
  def customers
    # redirect_to search_v2_spotlight_index_path unless privilege?(:view_contacts)

    @@searchable_klasses = ['User', 'company']
    search
  end

  # Forums scoped spotlight search
  #
  def forums
    # redirect_to search_v2_spotlight_index_path unless privilege?(:view_forums)

    @@searchable_klasses = ['Topic']
    search
  end

  # Solutions scoped spotlight search
  #
  def solutions
    # redirect_to search_v2_spotlight_index_path unless privilege?(:view_solutions)

    @@searchable_klasses = ['Solution::Article']
    search
  end

  private

    # Need to add provision to pass params & context
    #
    def search
      @es_results = Search::V2::SearchRequestHandler.new(current_account.id, :agent_spotlight, searchable_types).fetch(search_term: @search_key)
      @result_set = Search::Utils.load_records(@es_results, @@esv2_spotlight_models.dclone, current_account.id)

      process_results
      handle_rendering
    end

    # Types to be passed to service code to scan
    #
    def searchable_types
      searchable_klasses.collect {
        |klass| klass.demodulize.downcase
      }
    end

    def searchable_klasses
      @@searchable_klasses ||= esv2_klasses
    end

    ###############################################
    ### Override in child controllers if needed ###
    ###############################################

    def esv2_klasses
      Array.new.tap do |model_names|
        model_names.concat(['Helpdesk::Ticket', 'Helpdesk::Note'])

        model_names.concat(['User', 'Company']) if privilege?(:view_contacts)
        model_names.push('Topic')               if privilege?(:view_forums)
        model_names.push('Solution::Article')   if privilege?(:view_solutions)
      end
    end

    # Reconstructing ES results
    #
    def process_results
      @result_set.each do |result|
        @result_json[:results] << send(%{#{result.class.model_name.singular}_json}, result) if result
      end

      @total_pages    = @es_results['hits']['total'].to_i / 30
      @search_results = (@search_results.presence || []) + @result_set
    end

    # To-do: Add other necessary formats here
    #
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

    ######################
    ### Before filters ###
    ######################

    # To-do: Need to verify if needed
    #
    def set_search_sort_cookie
      cookies[:search_sort] = params[:search_sort] if params[:search_sort]
    end

    def initialize_search_parameters
      @search_key   = params[:term] || params[:search_key] || ''
      @search_sort  = params[:search_sort] || cookies[:search_sort]
      @result_json  = { :results => [], :current_page => 1 }
      @es_results   = []
      @current_page = params[:page].to_i.zero? ? 1 : params[:page].to_i
    end
end