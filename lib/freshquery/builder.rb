module Freshquery
  class Builder
    attr_reader :args, :error_response

    def initialize
      @args = {}
    end

    def query
      yield(@args)
      if @args.key?(:query)
        # If we add search_term in future exact_match should be set based on a logic on search_term
        # freshquery/utils/exact_match? method should be used
        @args[:exact_match] = false
        Rails.logger.info "FQL query - #{@args[:query]}"
        response = Freshquery::Runner.instance.construct_es_query(@args[:types].first, @args[:query])
        if response.valid?
          @args[:search_terms] = response.terms.to_json
          Rails.logger.info "FQL query terms - #{@args[:search_terms]}"
        else
          @error_response = response
          Rails.logger.error "FQL query error - #{@error_response.errors.messages.to_json}"
        end
      end
      @args.key?(:es_params) ? @args[:es_params].merge!(default_es_params) : @args[:es_params] = default_es_params
      @args[:current_page] = Freshquery::Constants::DEFAULT_PAGE unless @args.key?(:current_page)
      self
    end

    def check_query_validity(args)
      response = Freshquery::Runner.instance.construct_es_query(args[:types].first, args[:query])
      return response
    end

    def response
      if @error_response.blank?
        begin
          keys = [:account_id, :context, :exact_match, :es_models, :current_page, :offset, :types, :es_params]
          @records = SearchService::QueryHandler.new(args.slice(*keys)).query_results
        rescue Exception => e
          Rails.logger.error "Searchv2 exception - FQL - #{e.message} - #{e.backtrace.first}"
          NewRelic::Agent.notice_error(e)
          Freshquery::Utils.error_response(args[:es_params][:search_terms], :query, e.message)
        end
        response = Freshquery::Response.new(true, args[:es_params][:search_terms])
        response.items = @records
        response
      else
        @error_response
      end
    end

    def default_es_params
      {}.tap do |es_params|
        es_params[:search_terms] = @args.fetch(:search_terms, {})
        es_params[:account_id] = @args[:account_id]
        es_params[:offset] = (@args.fetch(:current_page, Freshquery::Constants::DEFAULT_PAGE) - 1) * Freshquery::Constants::DEFAULT_PER_PAGE
        es_params[:size] = Freshquery::Constants::DEFAULT_PER_PAGE
        es_params[:request_id] = Thread.current[:message_uuid].try(:first) || UUIDTools::UUID.timestamp_create.hexdigest
      end
    end
  end
end
