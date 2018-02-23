# Agent side autocomplete search
#
class Search::V2::Freshfone::AutocompleteController < ApplicationController

  include Search::V2::AbstractController
  
  before_filter :load_requester_with_id, only: [:contact_by_numbers], if: :customer_id_present?

  attr_accessor :search_results
  
  def contact_by_numbers
    if @customer.present?
      self.search_results[:results].push(format_customer_results(@customer))
    else
      @klasses  = ['User']
      @search_context = :requester_autocomplete

      search_by_context(:requester)
    end

    respond_to do |format|
      format.json { render :json => self.search_results.to_json }
    end
  end

  def customer_by_phone
    if numeric_search?(@search_key)
      @klasses  = ['Freshfone::Caller']
      @search_context = :ff_contact_by_caller
      search_by_context(:caller)
    else
      @klasses  = ['User']
      @search_context = :requester_autocomplete
      search_by_context(:requester)
    end

    respond_to do |format|
      format.json { render :json => self.search_results.to_json }
    end
  end
  
  def contact_by_numberfields
    @klasses  = ['User']
    @search_context = :ff_contact_by_numfields
    
    search_by_context(:contact)
    respond_to do |format|
        format.html { 
          render :partial => 'layouts/shared/freshfone/freshfone_search_results' , :object => search_results[:results] 
        }  
		end
  end

  private

  	##### Methods taken from freshfone/autocomplete controller #####
    #
    def numeric_search?(search_string)
  		regex_for_numbers = '^[0-9.]*$'
  		search_string.gsub(/[^0-9a-z]/i, '').match(regex_for_numbers)
  	end

  	def search_non_deleted?
  		params[:is_deleted] == "true"
  	end
    
    def load_requester_with_id
      @customer = current_account.all_users.where(id: params[:customer_id])
                                          .where("(phone <> '') OR (mobile <> '')").first
    end
    
    def customer_id_present?
      params[:customer_id].present?
    end
    #
    ################################################################
  
    def search_by_context(entity)
      search(esv2_autocomplete_models) do |results|
        results.each do |result|
          self.search_results[:results].push(safe_send("format_#{entity}_results", result))
        end
      end
    end
    
    def construct_es_params
      super.tap do |es_params|
        es_params[:is_deleted] = search_non_deleted?
        es_params[:phone_fields_str] = Freshfone::Search.custom_field_data_columns.join('\",\"')
        es_params[:phone_fields_arr] = Freshfone::Search.custom_field_data_columns
      end
    end
    
    ######## Reconstructing results ########
    #
    def format_requester_results(result)
      {	
        id:     result.id,
        value:  result.name,
        email:  result.email,
        phone:  result.phone,
        mobile: result.mobile,
        user_result: true
      } 
  	end

  	def format_contact_results(result)
      { 
        user:         result,
        id:           result.id,
        value:        result.name,
        phone:        result.phone,
        mobile:       result.mobile,
        company:      result.company.present? ? result.company.name : nil,
        custom_field: contact_custom_field(result), 
        custom_name:  Freshfone::Search.custom_field_column_names
      }
  	end

  	def format_customer_results(result)
      {
  			id:      result.id,
  			value:   result.name,
  			email:   result.email,
  			phone:   result.phone,
  			mobile:  result.mobile,
  			user_result: true
  		}
  	end

  	def contact_custom_field(contact) 
  		Freshfone::Search.custom_field_data_columns.map do |field|
  		  contact.flexifield[field]
  		end
  	end

  	def format_caller_results(result)
      {
        id:     result.id,
        value:  result.number
      }
  	end
    #
    ########################################

    def initialize_search_parameters
      super
      @no_render = true
      self.search_results = { results: [] }
    end

    # ESType - [model, associations] mapping
    # Needed for loading records from DB
    #
    def esv2_autocomplete_models
      @@esv2_freshfone_autocomplete ||= {
        'user'    => { model: 'User',               associations: [] },
        'caller'  => { model: 'Freshfone::Caller',  associations: [] }
      }
    end
end
