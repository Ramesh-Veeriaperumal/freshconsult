# frozen_string_literal: true

module CronWebhooks
  class CronApiWebhookWorker < BaseWorker
    include CronWebhooks::Constants
    require 'httparty'
    sidekiq_options queue: :cron_api_triggers, retry: 2, failures: :exhausted

    def perform(args)
      @args = HashWithIndifferentAccess.new(args)
      Rails.logger.info "Cron API worker started with params: #{@args[:actual_domain]}::#{@args[:account_type]}"
      url = "#{AppConfig['haproxy']['internal_domain']}/api/cron/trigger_cron_api"
      response = HTTParty.post(
        url,
        :body => { 'account_type' => @args[:account_type], 'name' => @args[:name], 'skip_blacklist_verification' => true }.to_json,
        :headers => { 'Host' => @args[:actual_domain], 'X-FORWARDED-PROTO' => 'https', 'Content-Type' => 'application/json', 'X-Freshdesk-Cron-WebHook-Key' => CRON_HOOK_ACCOUNT_AUTH_KEY }
      )
      raise "Failed in performing cron api worker #{response.code}" if response.code != 200

      Rails.logger.info "Cron API worker completed with params: #{@args[:actual_domain]}::#{@args[:account_type]}"
    rescue StandardError => e
      Rails.logger.info "Exception in Cron API worker: #{e}"
      NewRelic::Agent.notice_error(e, args: @args)
    end
  end
end
