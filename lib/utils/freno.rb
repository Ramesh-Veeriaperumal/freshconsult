require 'json'
require 'httparty'

module Utils
  module Freno
      FRENO_CHECK_SHARD_API = '/check/appname/mysql/'

      def get_replication_lag_for_shard(application_name, shard_name)
        # if shard name or application name is empty, replication lag can't be checked for the shard.
        return  0 if shard_name.blank? || application_name.blank?

        #form the check API endpoint URL
        check_shard_api_endpoint = FRENO_CHECK_SHARD_API
        check_shard_api_endpoint.gsub! 'appname', application_name
        check_shard_api_url = FrenoConfig['freno_base_url'] + check_shard_api_endpoint + shard_name

        # check replication lag API and return based on response code.
        Rails.cache.fetch(check_shard_api_url,  :expires => 10.second) do
          response = HTTParty.get(check_shard_api_url, timeout: 1)
          if response.code == 200 then
            return  0 # No replication lag found, return 0
          elsif response.code == 429 then
            # Replication lag has been found by Freno.
            return parse_api_response(response)
          elsif response.code == 417 then
            # This application has been explicitly throttled, wait for 10 minutes and check again.
            return 10 * 60
          else
            Rails.logger.debug("Warning: Freno API respons code: #{response.code} for shard: #{shard_name}")
            return -1
          end
        end

        # catch any exception from freno API calls and handle them
        rescue Exception => e
          NewRelic::Agent.notice_error(e, description: 'Error occurred in making Freno API call: #{e.message} ')
          Rails.logger.debug("Error occurred while making Freno check API call :: #{e.message}")
          return -1
      end

       def parse_api_response(response)
         parsed_json = JSON.parse(response.body)
         replag = parsed_json["Value"]
         if replag.blank? then
           return 0
         else
           return replag.to_i
         end
       rescue ArgumentError
         return 0
       end

      class ReplicationLagError < StandardError
        attr_accessor :lag
        def initialize(lag, message = "Replication lag")
          @lag = lag
          super(message)
        end
      end
  end

end