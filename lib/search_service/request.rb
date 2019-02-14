module SearchService
  class Request
    ES_TIMEOUT = 10
    attr_accessor :typhoeus_request, :account_id, :additional_info, :logger, :response

    def initialize(path, method, uuid, payload, headers, account_id, additional_info = {})
      @logger = SearchService::Logger.new(uuid, Search::Utils::SEARCH_LOGGING[:request])
      @account_id = account_id
      @additional_info = additional_info
      @typhoeus_request = Typhoeus::Request.new(path, method: method, body: payload, headers: headers, accept_encoding: 'gzip, deflate', timeout: ES_TIMEOUT)
      attach_callbacks
      @typhoeus_request.run
    end

    def attach_callbacks
      @typhoeus_request.on_failure do |response|
        @response = Response.new(response)
        log_details(@typhoeus_request) unless @response.code.zero?
        handle_failure
      end

      @typhoeus_request.on_success do |response|
        @response = Response.new(response)
        log_details(@typhoeus_request)
      end
    end

    def handle_failure
      error = @response.records

      if @response.timed_out?
        raise Errors::RequestTimedOutException.new(error['message'])
      elsif @response.code == 0
        raise Errors::ServerNotUpException.new(error['message'])
      elsif @response.code == 400
        if error['code'] == 'invalid_json'
          raise Errors::InvalidJsonException.new(error['message'])
        elsif error['code'] == 'invalid_field'
          raise Errors::InvalidFieldException.new(error['message'])
        elsif error['code'] == 'invalid_value'
          raise Errors::InvalidValueException.new(error['message'])
        elsif error['code'] == 'duplicate_value'
          raise Errors::DuplicateValueException.new(error['message'])
        elsif error['code'] == 'data_type_mismatch'
          raise Errors::DatatypeMismatchException.new(error['message'])
        elsif error['code'] == 'missing_field'
          raise Errors::MissingFieldException.new(error['message'])
        elsif error['code'] == 'missing_dependency'
          raise Errors::MissingDependencyException.new(error['message'])
        elsif error['code'] == 'template_not_found'
          raise Errors::TemplateNotFoundException.new(error['message'])
        elsif error['code'] == 'missing_template_param'
          raise Errors::MissingTemplateParamException.new(error['message'])
        elsif error['code'] == 'query_template_error'
          raise Errors::QueryTemplateException.new(error['message'])
        elsif error['code'] == 'invalid_template_definition'
          raise Errors::InvalidTemplateDefinitionException.new(error['message'])
        else
          raise Errors::BadRequestException.new(error['message'])
        end
      elsif @response.code == 401
        raise Errors::AuthorizationException.new(error['message'])
      elsif @response.code == 403
        # Account Suspended
        raise Errors::AccountSupendedException.new(error['message'])
      elsif @response.code == 404
        # NOT_FOUND
        unless(@response.request.original_options[:method].eql?(:delete))
          raise Errors::DefaultSearchException.new(error['message'])
        end
      elsif @response.code == 409
        # Version Conflict
      elsif @response.code == 429
        # TOO_MANY_REQUESTS
        raise Errors::IndexRejectedException.new(error['message'])
      elsif @response.code == 500
        if error['code'] == 'template_render_error'
          raise Errors::TemplateRenderException.new(error['message'])
        elsif error['code'] == 'circuit_breaker_opened'
          raise Errors::CircuitBreakerOpenedException.new(error['message'])
        elsif error['code'] == 'service_unavailable'
          raise Errors::ServiceUnavailableException.new(error['message'])
        elsif error['code'] == 'gateway_timeout'
          raise Errors::GatewayTimeoutException.new(error['message'])
        elsif error['code'] == 'bad_gateway'
          raise Errors::BadGatewayException.new(error['message'])
        elsif error['code'] == 'operation_timeout'
          raise Errors::OperationTimeoutException.new(error['message'])
        elsif error['code'] == 'response_error'
          raise Errors::BadResponseException.new(error['message'])
        else
          raise Errors::DefaultSearchException.new(error['message'])
        end
      else
        raise Errors::DefaultSearchException.new(error['message'])
      end
    end

    def log_details(request)
      logger.log_info(request, @response, @account_id, { took_time: @response.headers["X-Search-Took-Time"] }.merge(@additional_info))
    end
  end
end
