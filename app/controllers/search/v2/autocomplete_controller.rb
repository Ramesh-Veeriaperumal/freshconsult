# Agent side autocomplete search
#
class Search::V2::AutocompleteController < ApplicationController

  before_filter :initialize_search_parameters

  attr_accessor :search_key, :search_context, :searchable_klass, :records_from_db, :search_results

  def agents
    @search_context   = :agent_autocomplete
    @searchable_klass = 'User'
    @es_params        = {
      search_term: @search_key,
      exact_match: @exact_match
    }.merge(ES_V2_BOOST_VALUES[:agent_autocomplete])

    search.each do |document|
      @search_results[:results].push(*[{
        id: document.email,
        value: document.name,
        user_id: document.id
      }])
    end
    handle_rendering
  end

  def requesters
    @search_context   = :requester_autocomplete
    @searchable_klass = 'User'
    @es_params        = {
      search_term: @search_key,
      exact_match: @exact_match
    }.merge(ES_V2_BOOST_VALUES[:requester_autocomplete])

    search.each do |document|
      @search_results[:results].push(*document.search_data)
    end
    handle_rendering
  end

  def companies
    @search_context   = :company_autocomplete
    @searchable_klass = 'Company'
    @es_params        = {
      search_term: @search_key,
      exact_match: @exact_match
    }

    search.each do |document|
      @search_results[:results].push(*[{
        id: document.id,
        value: document.name
      }])
    end
    handle_rendering
  end

  def tags
    @search_context   = :tag_autocomplete
    @searchable_klass = 'Helpdesk::Tag'
    @es_params        = {
      search_term: @search_key
    }

    search.each do |document|
      @search_results[:results].push(*[{
        value: document.name
      }])
    end
    handle_rendering
  end

  private

    # Make the search request to ES
    #
    def search
      begin
        es_results = Search::V2::SearchRequestHandler.new(current_account.id,
                                                            @search_context,
                                                            searchable_type.to_a
                                                          ).fetch(@es_params)
        @records_from_db = Search::Utils.load_records(
                                                        es_results, 
                                                        esv2_autocomplete_models.dclone, 
                                                        {
                                                          current_account_id: current_account.id,
                                                          page: Search::Utils::DEFAULT_PAGE,
                                                          from: Search::Utils::DEFAULT_OFFSET
                                                        }
                                                      )
      rescue => e
        Rails.logger.error "Searchv2 exception - #{e.message}"
        NewRelic::Agent.notice_error(e)
        @records_from_db = []
      end
    end

    # Type to be passed to service code to scan
    #
    def searchable_type
      @searchable_klass.demodulize.downcase
    end

    def handle_rendering
      respond_to do |format|
        format.json { render :json => @search_results.to_json }
      end
    end

    def initialize_search_parameters
      @search_key       = params[:q] || ''
      @records_from_db  = []
      @search_results   = { results: [] }

      if Search::Utils.exact_match?(@search_key)
        @search_key   = Search::Utils.extract_term(@search_key)
        @exact_match  = true
      end
    end

    # ESType - [model, associations] mapping
    # Needed for loading records from DB
    #
    def esv2_autocomplete_models
      @@esv2_agent_autocomplete ||= {
        'user'    => { model: 'User',           associations: [{ :account => :features }, :user_emails] },
        'company' => { model: 'Company',        associations: [] },
        'tag'     => { model: 'Helpdesk::Tag',  associations: [] }
      }
    end
end
