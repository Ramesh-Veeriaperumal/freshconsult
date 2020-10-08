# Article Specific searches
#
class Search::V2::SolutionsController < ApplicationController

  include Search::SearchResultJson
  include Search::V2::AbstractController
  helper Search::SearchHelper

  before_filter :load_ticket, :only => [:related_solutions, :search_solutions]
  before_filter :detect_multilingual_search, only: [:related_solutions, :search_solutions]
    
  # Find solutions for ticket
  #
  def related_solutions
    @es_search_term = @ticket.subject
    search_and_assign
    render partial: 'search/solutions/results'
  end

  # Find solutions for insert_solution search
  # _Note_: Need to check if can be handled with related_solutions
  #
  def search_solutions
    search_and_assign
    render partial: 'search/solutions/results'
  end
  
  private
    
    def construct_es_params
      super.tap do |es_params|
        es_params[:language_id]         = params[:language_id] || Language.for_current_account.id
        es_params[:article_category_id] = params[:category_id].to_i if params[:category_id].present?
        es_params[:article_folder_id]   = params[:folder_id].to_i if params[:folder_id].present?
        es_params[:sort_by]             = @search_sort
        es_params[:sort_direction]      = @sort_direction
        es_params[:size]                = @size
        es_params[:from]                = @offset
      end
    end

    def search_and_assign
      search(esv2_agent_models) do |results|
        @search_results = results #=> @search_results used in rendering
      end
    end
  
    def initialize_search_parameters
      super
      @klasses            = ['Solution::Article']
      @search_context     = :agent_insert_solution
      @suggest            = true
      @no_render          = true
    end
    
    # @ticket used in search_solutions view
    #
    def load_ticket
      @ticket = current_account.tickets.find_by_id(params[:ticket])
    end

		# Hack for getting language and hitting corresponding alias
		# Probably will be moved to search/search_controller when dynamic solutions goes live
    def detect_multilingual_search
      if params[:language].present? && current_account.es_multilang_solutions_enabled?
        @es_locale = params[:language].presence
      end
    end
  
    # ESType - [model, associations] mapping
    # Needed for loading records from DB
    #
    def esv2_agent_models
      @@esv2_agent_solution ||= {
        'article' => { model: 'Solution::Article',  associations: [ :folder, :article_body ] }
      }
    end
end