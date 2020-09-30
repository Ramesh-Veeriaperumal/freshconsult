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
        @templates        = args[:templates]
        @count_request    = args[:count_request] || false
        @records          = []
      end

      def query_results
        begin
          # Temp hack for handling pubsub/souq cases.
          handle_spl_queries

          @locale = SearchService::Utils.valid_locale(@searchable_types, @locale)
          template_name = Search::Utils.get_template_id(@search_context, @exact_match, @locale)
          paginate_params = { page: @current_page.to_i, from: @offset }
          request_id = @es_params.delete(:request_id)
          @records = SearchService::Client.new(@account_id).query(
            SearchService::Utils.construct_payload(@searchable_types, template_name, @es_params, @locale),
            request_id,
            { search_type: template_name }
          )
          @records = @count_request ? @records : @records.records_with_ar(@es_models, @account_id, paginate_params)
        rescue Exception => e
          Rails.logger.error "Searchv2 exception - #{e.message} - #{e.backtrace.first}"
          NewRelic::Agent.notice_error(e)
          @records = Search::Utils.safe_send(:wrap_paginate, [], @current_page, @offset, 0)
        end
        @records
      end

      def construct_query
        handle_spl_queries

        @locale = SearchService::Utils.valid_locale(@searchable_types, @locale)
        template_name = Search::Utils.get_template_id(@search_context, @exact_match, @locale)

        SearchService::Utils.construct_mq_payload(@searchable_types, template_name, @es_params, false)
      end

      def multi_query_results(request_params)
        request_id = @es_params.delete(:request_id)
        template_name = Search::Utils.get_template_id(@search_context, @exact_match, @locale)
        paginate_params = { page: @current_page.to_i, from: @offset }
        response = SearchService::Client.new(@account_id).multi_query(request_params, request_id, { search_type: template_name })
        @records = response.records['results'].map do |context, context_response|
            {
              :context => Search::Utils.context_mapping(context),
              :data    => response.records_with_ar(@es_models, @account_id, paginate_params, context_response)
            }
        end
      rescue Exception => e
        Rails.logger.error "Searchv2 mquery exception - #{e.message} - #{e.backtrace.first}"
        NewRelic::Agent.notice_error(e)
        @records = @templates.map do |context| 
          {:context => context, :data => Search::Utils.safe_send(:wrap_paginate, [], @current_page, @offset, 0)}
        end
      end

      private

        def handle_spl_queries
          if Account.current.es_v2_splqueries_enabled?
            template_key = Search::Utils.template_context(@search_context, @exact_match, @locale)
            @es_params[:search_term].to_s.gsub!(/([\(\)\[\]\{\}\?\\\"!\^\+\-\*\/:~])/,'\\\\\1') if Search::Utils::SPECIAL_TEMPLATES.has_key?(template_key)
          end
        end
    end

  end
end
