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
        @locale           = args[:locale]
        @records          = []
      end
      
      def query_results
        begin
          # Temp hack for handling pubsub/souq cases.
          if(Account.current.launched?(:es_v2_splqueries))
            template_key = Search::Utils.template_context(@search_context, @exact_match, @locale)
            @es_params[:search_term].to_s.gsub!(/([\(\)\[\]\{\}\?\\\"!\^\+\-\*\/:~])/,'\\\\\1') if Search::Utils::SPECIAL_TEMPLATES.has_key?(template_key)
          end

          es_results = SearchRequestHandler.new(@account_id,
            Search::Utils.template_context(@search_context, @exact_match, @locale),
            @searchable_types,
            @locale
          ).fetch(@es_params)

          @records = Search::Utils.load_records(es_results, @es_models,
            {
              current_account_id: @account_id,
              page: @current_page,
              es_offset: @offset
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