# Agent side autocomplete search
#
class Search::V2::AutocompleteController < ApplicationController

  include Search::V2::AbstractController

  attr_accessor :search_results

  skip_before_filter :check_privilege, if: :customer_portal?

  def requesters
    @klasses        = ['User']
    @search_context = :requester_autocomplete

    if skip_auto_complete? and !@search_key.match(AccountConstants::EMAIL_REGEX).present?
      handle_rendering
    else
      @exact_match = true if skip_auto_complete?
      search(esv2_autocomplete_models) do |results|
        results.each do |result|
          self.search_results[:results].push(*result.search_data)
       end
      end
    end
  end

  def agents
    @klasses        = ['User']
    @search_context = :agent_autocomplete

    search(esv2_autocomplete_models) do |results|
      results.each do |result|
        self.search_results[:results].push(*[{
          id: result.id,
          value: result.name,
          email: result.email,
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
    if customer_portal? && !check_user_permission
      self.search_results[:results] = []
      handle_rendering
    else
      @klasses        = ['User']
      @search_context = :portal_company_users
      search(esv2_autocomplete_models) do |results|
        results.each do |result|
          self.search_results[:results].push(*result.search_data)
        end
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

    def skip_auto_complete?
      current_account.auto_complete_off_enabled? and !current_user.privilege?(:view_contacts)
    end

    def construct_es_params
      default_es_params = super.merge(ES_V2_BOOST_VALUES[@search_context] || {})
      default_es_params.merge!({company_ids: [params[:customer_id].to_i]}) if @search_context == :portal_company_users
      default_es_params
    end

    def handle_rendering
      respond_to do |format|
        format.json { render :json => self.search_results.to_json }
      end
    end

    def initialize_search_parameters
      super
      self.search_results = {results: []}
    end

    # ESType - [model, associations] mapping
    # Needed for loading records from DB
    #
    def esv2_autocomplete_models
      @@esv2_agent_autocomplete ||= {
        'user'    => { model: 'User',           associations: [:user_emails] },
        'company' => { model: 'Company',        associations: [] },
        'tag'     => { model: 'Helpdesk::Tag',  associations: [] }
      }
    end

    def check_user_permission
      current_user && current_user.contractor? && current_user.company_ids.include?(params[:customer_id].to_i)
    end

    def customer_portal?
      action == :company_users && params[:customer_portal].to_bool 
    end
end
