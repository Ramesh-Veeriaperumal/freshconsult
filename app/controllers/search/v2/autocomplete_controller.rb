# Agent side autocomplete search
#
class Search::V2::AutocompleteController < ApplicationController

  include Search::V2::AbstractController

  attr_accessor :search_results

  skip_before_filter :check_privilege, :only => [:company_users]
  before_filter :access_denied, :unless => :logged_in?

  def requesters
    @klasses        = ['User']
    @search_context = :requester_autocomplete

    search(esv2_autocomplete_models) do |results|
      results.each do |result|
        self.search_results[:results].push(*result.search_data)
      end
    end
  end

  def agents
    @klasses        = ['User']
    @search_context = :agent_autocomplete

    search(esv2_autocomplete_models) do |results|
      results.each do |result|
        self.search_results[:results].push(*[{
          id: result.email,
          value: result.name,
          user_id: result.id,
          profile_img: result.avatar.nil? ? false : result.avatar.expiring_url(:thumb, 300)
        }])
      end
    end
  end

  def companies
    @klasses        = ['Company']
    @search_context = :company_autocomplete

    search(esv2_autocomplete_models) do |results|
      results.each do |result|
        self.search_results[:results].push(*[{
          id: result.id,
          value: result.name
        }])
      end
    end
  end

  def company_users
    @klasses        = ['User']
    @search_context = :portal_company_users

    if params[:customer_id].present? and current_user.company_ids.include?(params[:customer_id].to_i)
      @customer_id = params[:customer_id].to_i
    elsif current_user.client_manager
      @customer_id = current_user.company.try(:id)
    end

    search(esv2_autocomplete_models) do |results|
      results.each do |result|
        self.search_results[:results].push(*[{
          id: result.id,
          value: result.name,
          email: result.email
        }])
      end
    end
  end

  def tags
    @klasses        = ['Helpdesk::Tag']
    @search_context = :tag_autocomplete

    search(esv2_autocomplete_models) do |results|
      results.each do |result|
        self.search_results[:results].push(*[{
          value: result.name, id: result.id
        }])
      end
    end
  end

  private

    def construct_es_params
      super.tap do |es_params|
        es_params[:company_ids] = [@customer_id]
      end.merge(ES_V2_BOOST_VALUES[@search_context] || {})
    end

    def handle_rendering
      respond_to do |format|
        format.json { render :json => self.search_results.to_json }
      end
    end

    def initialize_search_parameters
      super
      self.search_results = { results: [] }
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
