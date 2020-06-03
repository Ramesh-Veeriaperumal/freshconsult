require 'json'
require 'httparty'

module Utils
  module Freno
    include Redis::OthersRedis

    FRENO_CHECK_SHARD_API = '/check/%{appname}/mysql/'.freeze
    FRENO_FAILURE_DELAY_KEY = 'FRENO_FAILURE_DELAY'.freeze
    BACKOFF_DELAY = 10

    def get_replication_lag_for_shard(application_name, shard_name, expiry = 10.seconds)
      # if shard name or application name is empty, replication lag can't be checked for the shard.
      # can ignore replication lag for Sandbox
      return 0 if shard_name.blank? || application_name.blank? || shard_name == SANDBOX_SHARD_CONFIG

      freno_url = freno_api_url(application_name, shard_name)
      # check replication lag API and return based on response code.
      Rails.cache.fetch(freno_url, expires_in: expiry) do
        response = HTTParty.get(freno_url, timeout: 1)
        if response.code == 200
          # No replication lag found, return 0
          return 0
        elsif response.code == 429
          # Replication lag has been found by Freno.
          return parse_api_response(response)
        elsif response.code == 417
          # This application has been explicitly throttled, wait for 10 minutes and check again.
          return 10 * 60
        elsif response.code == 404
          return -1
        elsif response.code == 500
          Rails.logger.error("Warning: Freno API returned 500 for shard: #{shard_name}")
          return freno_failure_delay
        elsif response.code == 503
          Rails.logger.error("Warning: Freno API returned 503 for shard: #{shard_name}")
          return freno_failure_delay
        else
          Rails.logger.error("Warning: Freno API response code: #{response.code} for shard: #{shard_name}")
          NewRelic::Agent.notice_error("Freno API Error :: API response: #{response.code} for shard: #{shard_name}")
          return freno_failure_delay
        end
      end
    rescue Net::OpenTimeout => e
      NewRelic::Agent.notice_error(e, description: "Timeout when connecting to Freno: #{e.message}")
      Rails.logger.debug("Timeout while making Freno check API call :: #{e.message}")
      return freno_failure_delay
    rescue Net::ReadTimeout => e
      NewRelic::Agent.notice_error(e, description: "Timeout when reading from Freno: #{e.message}")
      Rails.logger.debug("Timeout while reading Freno response :: #{e.message}")
      return freno_failure_delay
    rescue StandardError => e
      NewRelic::Agent.notice_error(e, description: "Error occurred in making Freno API call: #{e.message}")
      Rails.logger.debug("Error occurred while making Freno check API call :: #{e} :: #{e.message}")
      return -1
    end

    def parse_api_response(response)
      parsed_json = JSON.parse(response.body)
      replag = parsed_json['Value']
      if replag.blank?
        return 0
      else
        return replag.to_i
      end
    rescue ArgumentError
      return 0
    end

    def freno_failure_delay
      Rails.cache.fetch(FRENO_FAILURE_DELAY_KEY, expires_in: 30.seconds) do
        redis_value = get_others_redis_key(FRENO_FAILURE_DELAY_KEY)
        (redis_value || BACKOFF_DELAY).to_i
      end
    end

    # form the check API endpoint URL
    def freno_api_url(app_name, shard)
      check_shard_api_endpoint = format(FRENO_CHECK_SHARD_API, appname: app_name)
      FrenoConfig['freno_base_url'] + check_shard_api_endpoint + shard
    end

    class ReplicationLagError < StandardError
      attr_accessor :lag
      def initialize(lag, message = 'Replication lag')
        @lag = lag
        super(message)
      end
    end
  end
end
