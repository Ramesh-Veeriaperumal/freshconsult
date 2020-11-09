# frozen_string_literal: true

class Solution::KbserviceClearCacheWorker < BaseWorker
  sidekiq_options queue: :kbservice_clear_cache_worker, retry: 4, failures: :exhausted

  def perform(args)
    return unless Account.current.omni_bundle_account? && Account.current.launched?(:kbase_omni_bundle)

    args.symbolize_keys!
    @entity = args[:entity]
    acc = Account.current
    acc_domain = format(KbServiceConfig['domain'], domain: acc.full_domain)
    @endpoint = format(KbServiceConfig['api_endpoint'], domain: acc_domain)
    bearer_token = generate_bearer_token(acc_domain, acc.id, KbServiceConfig['secret_key'])
    invoke_call do
      request(KbServiceConfig['clear_cache_path'],
              { domains: DomainMapping.where(account_id: acc.id).pluck(:domain),
                entity: @entity },
              bearer_token)
    end
  end

  private

    def generate_bearer_token(acc_domain, acc_id, secret_key)
      'Bearer ' + JWT.encode({ account_domain: acc_domain, account_id: acc_id, source: 'helpkit' }, secret_key)
    end

    def invoke_call
      @response_data = yield
    end

    def kbservice_connection
      Faraday.new(url: CGI.escape(@endpoint)) do |conn|
        conn.request :json
        conn.adapter Faraday.default_adapter
      end
    end

    def request(path, payload, bearer_token)
      conn = kbservice_connection
      conn.headers = { 'Accept' => 'application/json',
                       'Content-Type' => 'application/json',
                       'Authorization' => bearer_token }
      response = begin
        conn.post do |req|
          req.url "#{@endpoint}#{path}"
          req.body = payload
        end
      end
      if response.status == 200
        Rails.logger.error "KBService Cache Cleared:: For domains #{payload}"
      else
        Rails.logger.error "KBService API Error Response :: #{response.status}"
        NewRelic::Agent.notice_error("KBService API Error Response :: #{response.status}")
      end
    rescue StandardError => e
      Rails.logger.error "KBService API Error Response :: #{e}"
      NewRelic::Agent.notice_error(e)
    end
end
