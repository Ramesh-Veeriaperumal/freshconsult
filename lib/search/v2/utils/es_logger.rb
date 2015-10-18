module Search
  module V2
    module Utils

      ############################
      ### Custom Logger for ES ###
      ############################

      class EsLogger

        attr_accessor :log_uuid

        # [aad4a930a1d185210c27d1b0ec286197] Request message
        # [aad4a930a1d185210c27d1b0ec286197] Response message
        #
        # Generating a time-based UUID to log and track request and response
        #
        def initialize
          @log_uuid = Digest::MD5.hexdigest(Time.zone.now.to_s)
        end
        
        # [01dc7d52106eabd6a8e8d173f8cb9b38] [2015-10-17 18:05:54:271] GET localhost:9200/_search
        # '{"query":{"match":{"query_string":"term*"}}}'
        #
        # (*) Log timestamp in IST
        # (*) Log HTTP method
        # (*) Log endpoint
        # (*) Log payload based on check?
        #
        def log_request(endpoint, http_method='get', payload=nil)
          output = []
          
          output << http_method.to_s.upcase
          output << endpoint
          output << payload.inspect if payload

          log(output.join(' '))
        end

        # [01dc7d52106eabd6a8e8d173f8cb9b38] [2015-10-17 18:08:54:448] [200] (20 msec)
        #
        # (*) Log timestamp in IST
        # (*) Log response code
        # (*) Log time taken
        # (*) Log error message if any
        # (*) Log payload based on check?
        #
        def log_response(response_code, response_time=nil, error_msg=nil, payload=nil)
          output = []

          output << "[#{response_code}]"
          output << "(#{response_time} msec)" if response_time
          output << "(#{error_msg})" if error_msg
          output << payload.inspect if payload

          log(output.join(' '))
        end

        private

          # 2015-10-15 11:36:15:542
          #
          # Get timestamp event is happening at in custom format
          #
          def timestamp
            Time.zone.now.strftime('%Y-%m-%d %H:%M:%S:%L')
          end

          # Log filepath
          #
          def log_path
            @@esv2_log_path ||= "#{Rails.root}/log/esv2_requests.log"
          end 

          # Logging mechanism
          #
          def log_device
            @@esv2_logger ||= Logger.new(log_path)
          end

          # Logging function
          #
          def log(message, level='info')
            begin
              log_device.send(level, "[#{@log_uuid}] [#{timestamp}] #{message}")
            rescue Exception => e
              Rails.logger.debug("Exception in ES Logger :: #{e.message}")
              NewRelic::Agent.notice_error(e)
            end
          end
      end

    end
  end
end