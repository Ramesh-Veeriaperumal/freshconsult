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
        def initialize(uuid)
          @log_uuid = uuid || UUIDTools::UUID.timestamp_create.hexdigest
        end

        # [01dc7d52106eabd6a8e8d173f8cb9b38] [2015-10-17 18:05:54:271] GET localhost:9200/_search
        # '{"query":{"match":{"query_string":"term*"}}}'
        #
        # (*) Log timestamp in UTC
        # (*) Log HTTP method
        # (*) Log endpoint
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
        # (*) Log timestamp in UTC
        # (*) Log response code
        # (*) Log time taken
        # (*) Log error message if any
        #
        def log_response(response_code, response_time=nil, error_msg=nil, payload=nil)
          output = []

          output << "[#{response_code}]"
          output << "(#{response_time} msec)" if response_time
          output << "(#{error_msg})" if error_msg
          output << payload.inspect if payload

          log(output.join(' '))
        end

        def track_hits(account_id,cluster, search_type,response_code, response_time=nil, hits=nil, request_payload=nil)
          output = []

          output << "account_id=#{account_id}"
          output << "cluster=#{cluster}"
          output << "search_type=#{search_type}"
          output << "response_code=#{response_code}"
          output << "response_time=#{response_time}"
          output << "hits=#{hits}"
          output << "request_payload=#{request_payload}"

          track(output.join(' '))
        end

        def log_timestamps(timestamps)
          return if timestamps.blank?
          output = []
          end_time = Search::Job.es_version/1000
          t = timestamps.shift
          total_timespent = end_time - t
          output << "start=#{t}"
          timestamps.each_with_index do |stamp, i|
            stamp = stamp.to_i
            output << "h#{i}_pick=#{stamp}, h#{i}_spent=#{stamp - t}"
            t = stamp
          end
          output << "end=#{end_time}, end_spent=#{end_time - t}, total=#{total_timespent}"
          log(output.join(', '))
        end

        # For easily parseble
        # (*) Log account_id
        # (*) Log cluster_name
        # (*) Log search_type
        # (*) Log response code
        # (*) Log time taken by libcurl client(typhoeus)
        # (*) Log time taken by es if timedout it should be -1
        # (*) Log error message if any
        #
        def log_details(account_id,
                        cluster,
                        search_type,
                        response_code,
                        client_time,
                        starttransfer_time,
                        appconnect_time,
                        pretransfer_time,
                        connect_time,
                        namelookup_time,
                        redirect_time,
                        es_response_time=nil)
          output = []
          output << "account_id=#{account_id}"
          output << "cluster=#{cluster}"
          output << "search_type=#{search_type}"
          output << "response_code=#{response_code}"
          output << "client_time=#{client_time}"
          output << "starttransfer_time=#{starttransfer_time}"
          output << "appconnect_time=#{appconnect_time}"
          output << "pretransfer_time=#{pretransfer_time}"
          output << "connect_time=#{connect_time}"
          output << "namelookup_time=#{namelookup_time}"
          output << "redirect_time=#{redirect_time}"
          output << "es_response_time=#{es_response_time}"

          log(output.join(', '))
        end

        private

        # 2015-10-15 11:36:15:542
        #
        # Get timestamp event is happening at in custom format
        #
        def timestamp
          Time.zone.now.utc.strftime('%Y-%m-%d %H:%M:%S:%L')
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

        def track_device
          @@esv2_tracker ||= Logger.new("#{Rails.root}/log/esv2_hits.log")
        end

        # Logging function
        #
        def log(message, level='info')
          begin
            log_device.send(level, "[#{@log_uuid}] [#{timestamp}] #{message}")
          rescue Exception => e
            Rails.logger.error("[#{@log_uuid}] Exception in ES Logger :: #{e.message}")
            NewRelic::Agent.notice_error(e)
          end
        end

        def track(message, level='info')
          begin
            track_device.send(level, "[#{@log_uuid}] [#{timestamp}] #{message}")
          rescue Exception => e
            Rails.logger.error("[#{@log_uuid}] Exception in ES Logger :: #{e.message}")
            NewRelic::Agent.notice_error(e)
          end
        end
      end

    end
  end
end
