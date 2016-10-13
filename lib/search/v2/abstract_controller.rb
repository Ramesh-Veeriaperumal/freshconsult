# Abstract Stub that defines flow of controller logic common for V2 controllers
# Most values are standard
#
module Search::V2::AbstractController

  extend ActiveSupport::Concern
  #-----------------------------#
  #-- Instance variables used --#
  #-----------------------------#

  # search_context    #=> Context to pick ES template
  # current_page      #=> Current page for pagination
  # size              #=> Limit of records on ES side
  # offset            #=> Offset on ES side 
  # no_render         #=> Boolean to render/not render
  # klasses           #=> The model classes being scoped
  # search_key        #=> Raw input from user
  # exact_match       #=> Partial/Exact match boolean
  # es_search_term    #=> Sanitized term sent to ES
  # es_results        #=> Results collected from ES
  # result_set        #=> Results collected from DB

  included do
    before_filter :initialize_search_parameters
  end

  class_eval do
    private

      # Method that makes call to ES and loads AR results
      #
      def search(es_models)
        @result_set = Search::V2::QueryHandler.new({
          account_id:   current_account.id,
          context:      @search_context,
          exact_match:  @exact_match,
          es_models:    es_models,
          current_page: @current_page,
          offset:       @offset,
          types:        searchable_types,
          es_params:    construct_es_params
        }).query_results
        
        yield(@result_set) if block_given?
        process_results
      end

      # Types corresponding to the model classes
      # Invoked by 'search'
      #
      def searchable_types
        searchable_klasses.collect {
          |klass| klass.demodulize.downcase
        }
      end

      # Model classes scoped in the current action
      # Invoked by 'searchable_types'
      # _Note_: Define in inheriting class
      #
      def searchable_klasses
        @klasses ||= Array.new
      end

      # Model classes scoped in the current controller (Privilege Based)
      # _Note_: Define in inheriting class
      #
      def esv2_klasses
        Array.new
      end

      # Params constructed to be passed to ES request
      # Invoked by 'search', after 'searchable_types'
      # _Note_: Define in inheriting class
      #
      def construct_es_params
        { 
          search_term: @es_search_term,
          account_id: current_account.id,
          request_id: request.try(:uuid)
        }
      end

      # Reconstruction of AR result set to JSON, etc if any
      # Invoked by 'search', after 'construct_es_params'
      # _Note_: Define in inheriting class
      #
      def process_results
        # Do stuff here
        handle_rendering unless @no_render
      end

      # Rendering of templates, format based responses, etc
      # Invoked by 'search', after 'process_results'
      # _Note_: Define in inheriting class
      #
      def handle_rendering
        respond_to do |format|
          format.html {}
          format.json {}
          format.js {}
        end
      end

      # Before filter to construct parameters
      #
      def initialize_search_parameters
        @search_key     = (params[:term] || params[:search_key] || params[:q] || '')
        @exact_match    = true if Search::Utils.exact_match?(@search_key)
        @es_search_term = Search::Utils.extract_term(@search_key, @exact_match)

        limit           = (params[:max_matches] || params[:limit]).to_i
        @size           = (limit.zero? or (limit > Search::Utils::MAX_PER_PAGE)) ? Search::Utils::MAX_PER_PAGE : limit
        @current_page   = (params[:page].to_i.zero? ? Search::Utils::DEFAULT_PAGE : params[:page].to_i)
        @offset         = @size * (@current_page - 1)
      end
  end

end