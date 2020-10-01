module Freshquery
  class QueryHandler
    def initialize(args = {})
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
        if Account.current.es_v2_splqueries_enabled?
          template_key = Search::Utils.template_context(@search_context, @exact_match, @locale)
          @es_params[:search_term].to_s.gsub!(/([\(\)\[\]\{\}\?\\\"!\^\+\-\*\/:~])/, '\\\\\1') if Search::Utils::SPECIAL_TEMPLATES.key?(template_key)
        end

        @locale = SearchService::Utils.valid_locale(@searchable_types, @locale)
        template_name = Search::Utils.get_template_id(@search_context, @exact_match, @locale)
        paginate_params = { page: @current_page.to_i, from: @offset }
        request_id = @es_params.delete(:request_id)

        @records = SearchService::Client.new(@account_id).query(
          SearchService::Utils.construct_payload(@searchable_types, template_name, @es_params, @locale),
          request_id,
          search_type: template_name
        ).records_with_ar(@es_models, @account_id, paginate_params)
      rescue Exception => e
        Rails.logger.error "Searchv2 exception - #{e.message} - #{e.backtrace.first}"
        NewRelic::Agent.notice_error(e)
        @records = Search::Utils.safe_send(:wrap_paginate, [], @current_page, @offset, 0)
      end
      @records
    end
  end
end
