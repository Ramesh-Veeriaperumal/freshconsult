# Agent side autocomplete search
#
class Search::V2::AutocompleteController < ApplicationController

  before_filter :initialize_search_parameters

  attr_accessor :search_key, :search_context, :searchable_klass, :records_from_db, :search_results

  # ESType - [model, associations] mapping
  # Needed for loading records from DB
  #
  @@esv2_autocomplete_models = {
    'user'    => { model: 'User',           associations: [{ :account => :features }, :user_emails] },
    'company' => { model: 'Company',        associations: [] },
    'tag'     => { model: 'Helpdesk::Tag',  associations: [] }
  }

  def agents
    @search_context   = :agent_autocomplete
    @searchable_klass = 'User'
    @es_params        = {
      search_term: @search_key,
      is_deleted: false,
      sort_by: 'name',
      sort_direction: 'asc',
      size: 100
    }.merge(ES_BOOST_VALUES[:agent_autocomplete])

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
      is_deleted: false,
      sort_by: 'name',
      sort_direction: 'asc',
      size: 100
    }.merge(ES_BOOST_VALUES[:requester_autocomplete])

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
      sort_by: 'name',
      sort_direction: 'asc',
      size: 100
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
      search_term: @search_key,
      sort_by: 'tag_uses_count',
      sort_direction: 'desc',
      size: 25
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
        @records_from_db = Search::Utils.load_records(es_results, @@esv2_autocomplete_models.dclone, current_account.id)
      rescue => e
        NewRelic::Agent.notice_error(e)
        @records_from_db = send("#{@search_context}_fallback")
      end
    end

    # Type to be passed to service code to scan
    #
    def searchable_type
      @searchable_klass.demodulize.downcase
    end

    # DB fallback for Agents
    #
    def agent_autocomplete_fallback
      current_account.technicians.where(['name like ? or email like ?', "%#{@search_key}%", "%#{@search_key}%"]).limit(100)
    end

    # DB fallback for Users
    #
    def requester_autocomplete_fallback
      current_account.users
                      .joins([:user_emails])
                      .where(helpdesk_agent: false)
                      .where(['name like ? or phone like ? or mobile like ? or user_emails.email like ?',
                              "%#{@search_key}%", "%#{@search_key}%", "%#{@search_key}%", "%#{@search_key}%"]).limit(100)
    end

    # DB fallback for Companies
    #
    def company_autocomplete_fallback
      current_account.companies.where(['name like ?' ,"%#{@search_key}%"]).select([:id, :name]).limit(100)
    end

    # DB fallback for Tags
    #
    def tag_autocomplete_fallback
      current_account.tags.select(:name).order('tag_uses_count desc').limit(25)
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
    end
end
