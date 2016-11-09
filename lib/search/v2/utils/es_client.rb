module Search
  module V2
    module Utils

      #####################################
      ### Custom Request Wrapper for ES ###
      #####################################

      class EsClient

        ES_TIME_DEFAULT=-1

        attr_accessor :method, :path, :payload, :logger, :response, :log_data

        def initialize(method, path, query_params={}, payload=nil, log_data=nil, request_uuid=nil, account_id=nil,cluster=nil,search_type=nil)
          @method     = method.to_sym
          @path       = query_params.present? ? "#{path}?#{query_params.to_query}" : path
          @payload    = payload
          @uuid       = request_uuid
          @logger     = EsLogger.new(@uuid)
          @log_data   = log_data
          @account_id = account_id.presence
          @cluster    = cluster.presence
          @search_type= search_type.presence
          @es_response_time = nil
          
          es_request
        end

        private

          # Prepares request and logs it
          # _Note_: If Typhoeus is not a preferred client, can change here alone.
          #
          def es_request
            request_to_es = Typhoeus::Request.new(@path, method: @method, body: @payload, headers: { 'X-Request-Id' => @uuid })
            attach_callbacks(request_to_es)

            logger.log_request(
                                request_to_es.url, 
                                request_to_es.original_options[:method],
                                (log_request_payload? ? request_to_es.original_options[:body] : nil)
                              )
            request_to_es.run
          end

          # Callback for handling errors, response
          #
          def attach_callbacks(request)
            request.on_failure do |response_from_es|
              @es_response_time = ES_TIME_DEFAULT
              es_response(response_from_es) unless response_from_es.code.zero?
              handle_failure(response_from_es)
            end

            request.on_success do |response_from_es|
              es_response(response_from_es)
            end
          end

          
          # Failures will be logged.
          # If anything specfic like retry, can put code here
          #
          def handle_failure(response_from_es)
            @response = {} #=> Received a non-successful http response.

            if response_from_es.timed_out?
              raise Errors::RequestTimedOutException.new(response_from_es.body)
            elsif response_from_es.code == 0
              raise Errors::ServerNotUpException.new(response_from_es.body)
            elsif response_from_es.code == 400
              raise Errors::BadRequestException.new(response_from_es.body)
            # elsif response_from_es.code == 401
              # UNAUTHORIZED
              # raise Errors::DefaultSearchException.new(response_from_es.body)
            # elsif response_from_es.code == 402
              # PAYMENT_REQUIRED
              # raise Errors::DefaultSearchException.new(response_from_es.body)
            # elsif response_from_es.code == 403
              # FORBIDDEN
              # raise Errors::DefaultSearchException.new(response_from_es.body)
            # elsif response_from_es.code == 404
              # NOT_FOUND
              # raise Errors::DefaultSearchException.new(response_from_es.body)
            # elsif response_from_es.code == 405
              # METHOD_NOT_ALLOWED
              # raise Errors::DefaultSearchException.new(response_from_es.body)
            # elsif response_from_es.code == 406
              # NOT_ACCEPTABLE
              # raise Errors::DefaultSearchException.new(response_from_es.body)
            # elsif response_from_es.code == 407
              # PROXY_AUTHENTICATION
              # raise Errors::DefaultSearchException.new(response_from_es.body)
            # elsif response_from_es.code == 408
              # REQUEST_TIMEOUT
              # raise Errors::DefaultSearchException.new(response_from_es.body)
            elsif response_from_es.code == 409
              # Conflict from ES due to OCC failure
              # Silent Ignore
            # elsif response_from_es.code == 410
              # GONE
            # elsif response_from_es.code == 411
              # LENGTH_REQUIRED
            # elsif response_from_es.code == 412
              # PRECONDITION_FAILED
            # elsif response_from_es.code == 413
              # REQUEST_ENTITY_TOO_LARGE
            # elsif response_from_es.code == 414
              # REQUEST_URI_TOO_LONG
            # elsif response_from_es.code == 415
              # UNSUPPORTED_MEDIA_TYPE
            # elsif response_from_es.code == 416
              # REQUESTED_RANGE_NOT_SATISFIED
            # elsif response_from_es.code == 417
              # EXPECTATION_FAILED
            # elsif response_from_es.code == 422
              # UNPROCESSABLE_ENTITY
            # elsif response_from_es.code == 423
              # LOCKED
            # elsif response_from_es.code == 424
              # FAILED_DEPENDENCY
            elsif response_from_es.code == 429
              # TOO_MANY_REQUESTS
              raise Errors::IndexRejectedException.new(response_from_es.body)
            # elsif response_from_es.code == 500
              # INTERNAL_SERVER_ERROR
            # elsif response_from_es.code == 501
              # NOT_IMPLEMENTED
            # elsif response_from_es.code == 502
              # BAD_GATEWAY
            # elsif response_from_es.code == 503
              # SERVICE_UNAVAILABLE
            # elsif response_from_es.code == 504
              # GATEWAY_TIMEOUT
            # elsif response_from_es.code == 505
              # HTTP_VERSION_NOT_SUPPORTED
            # elsif response_from_es.code == 506
              # INSUFFICIENT_STORAGE
            else
              raise Errors::DefaultSearchException.new(response_from_es.body)
            end
          end

          # Makes request, prepares response and logs it
          #
          def es_response(response_from_es)
            @response         = JSON.parse(response_from_es.body)
            @es_response_time ||= @response["took"]
            
            logger.log_response(
                                response_from_es.code, 
                                @es_response_time, 
                                @response["error"],
                                (log_response_payload? ? response_from_es.body : nil)
                              )

            if @search_type
              logger.log_details(
                                @account_id,
                                @cluster,
                                @search_type,
                                response_from_es.code,
                                response_from_es.total_time*1000, 
                                @es_response_time
                              )
              
             end
          end

          # Log payload in development and in other 
          # environments based on feature check
          #
          def log_payload?
            Account.current.try(:launched?, :es_payload_log) || (@log_data == Search::Utils::SEARCH_LOGGING[:all])
          end
          
          def log_request_payload?
            log_payload? || (@log_data == Search::Utils::SEARCH_LOGGING[:request])
          end
          
          def log_response_payload?
            log_payload? || (@log_data == Search::Utils::SEARCH_LOGGING[:response])
          end
      end

    end
  end
end