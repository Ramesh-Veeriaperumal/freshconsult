require 'omniauth/strategies/oauth'
require 'multi_json'

module OmniAuth
  module Strategies
    class Magento < OmniAuth::Strategies::OAuth
      option :name, "magento"

      def request_phase
        request_token = consumer.get_request_token({:oauth_callback => callback_url}, options.request_params)
        session['oauth'] ||= {}
        session['oauth'][name.to_s] = {'callback_confirmed' => request_token.callback_confirmed?, 'request_token' => request_token.token, 'request_secret' => request_token.secret}
        if request_token.callback_confirmed?
          redirect request_token.authorize_url(options[:authorize_params])
        else
          redirect request_token.authorize_url(options[:authorize_params].merge(:oauth_callback => callback_url))
        end

      rescue ::Timeout::Error => e
        fail!(:timeout, "Timeout error")
      rescue ::Net::HTTPFatalError, ::OpenSSL::SSL::SSLError => e
        fail!(:service_unavailable, "Service Unavailable")
      rescue ::OAuth::Unauthorized => e
        fail!(:invalid_credentials, e.request.body)
      rescue ::Net::HTTPRetriableError => e
        fail!(:invalid_credentials, e.message)
      rescue Exception => e 
        NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Problem in installing Magento application"}})
        fail!(:unknown_error, "Unknown Error")
      end

    def fail!(message_key, exception)
      exception = exception || 'Unknown error'
      error_message = url_encode exception
      query = Rack::Utils.parse_query(env['QUERY_STRING'])
      account_id = query['origin'].split('=')[1]
      location = "/"
      Sharding.select_shard_of(account_id) do
        account = Account.find(account_id)
        account.make_current
        location = "#{account.full_url}/integrations/magento/edit?error=#{error_message}"
      end
      [302, {"Location" => location,  'Content-Type'=> 'text/html'}, []]
    end

    end
  end
end