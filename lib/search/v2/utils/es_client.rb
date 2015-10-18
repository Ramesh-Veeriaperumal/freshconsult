module Search
  module V2
    module Utils

      #####################################
      ### Custom Request Wrapper for ES ###
      #####################################

      class EsClient

        attr_accessor :method, :path, :payload, :logger, :response

        def initialize(method, path, payload=nil)
          @method   = method.to_sym
          @path     = path
          @payload  = payload
          @logger   = EsLogger.new
          
          es_request
        end

        private

          # Prepares request and logs it
          # _Note_: If Typhoeus is not a preferred client, can change here alone.
          #
          def es_request
            request_to_es = Typhoeus::Request.new(@path, method: @method, body: @payload)
            attach_callbacks(request_to_es)

            logger.log_request(
                                request_to_es.url, 
                                request_to_es.original_options[:method],
                                (log_payload? ? request_to_es.original_options[:body] : nil)
                              )
            request_to_es.run
          end

          # Callback for handling errors, response
          #
          def attach_callbacks(request)
            request.on_failure do |response_from_es|
              es_response(response_from_es)
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
            if response_from_es.timed_out?
              # Retry?
            elsif response_from_es.code == 0
            elsif response_from_es.code == 400
              # Raise BadRequestError
            elsif response_from_es.code == 409
              # Conflict from ES due to OCC failure
              # Silent Ignore
            end
            # Received a non-successful http response.

            @response = {}
          end

          # Makes request, prepares response and logs it
          #
          def es_response(response_from_es)
            @response         = JSON.parse(response_from_es.body)
            
            logger.log_response(
                                response_from_es.code, 
                                @response["took"], 
                                @response["error"],
                                (log_payload? ? response_from_es.body : nil)
                              )
          end

          # Log payload in development and in other 
          # environments based on feature check
          # To-do: Need to verify
          #
          def log_payload?
            Rails.env.development? #|| Account.current.try(:launched?, :es_payload_log)
          end
      end

    end
  end
end