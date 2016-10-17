# The module that makes the call to search libraries from App side
# The results returned from ES are then loaded from DB and wrapped
#
module Search
  module V2

    class QueryHandler
      
      def initialize(args={})
        @account_id       = args[:account_id]
        @search_context   = args[:context]
        @exact_match      = args[:exact_match]
        @es_models        = args[:es_models]
        @current_page     = args[:current_page]
        @offset           = args[:offset]
        @searchable_types = args[:types]
        @es_params        = args[:es_params]
        @records          = []
      end
      
      def query_results
        begin
          es_results = SearchRequestHandler.new(@account_id,
            Search::Utils.template_context(@search_context, @exact_match),
            @searchable_types
          ).fetch(@es_params)

          @records = Search::Utils.load_records(es_results, @es_models,
            {
              current_account_id: @account_id,
              page: @current_page,
              from: @offset
            }
          )
        rescue Exception => e
          Rails.logger.error "Searchv2 exception - #{e.message} - #{e.backtrace.first}"
          NewRelic::Agent.notice_error(e)
          @records = []
        end
        @records
      end

    end

  end
end