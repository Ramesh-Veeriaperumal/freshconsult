module IntegrationServices::Services
  module OutlookContacts
    class OutlookContactsResource < IntegrationServices::GenericResource

      APP_NAME = Integrations::Constants::APP_NAMES[:outlook_contacts]

      def faraday_builder(b)
        super
        b.headers["Authorization"] = "Bearer #{@service.sync_account.oauth_token}"
        b.headers["Accept"] = "application/json"
        b.headers["Content-Type"] = "application/json"
        b.use FaradayMiddleware::FollowRedirects, limit: 3
        b.use FaradayMiddleware::Oauth2Refresh, { :oauth2_access_token => get_access_token_object, :limit => 3 }
      end

      def process_response(response, *success_codes, &block)
        if success_codes.include?(response.status)
          if response.env[:new_token]
            @service.sync_account.update_oauth_token(response.env[:new_token])
            http_reset
          end
          yield parse(response.body)
        elsif response.status.between?(400, 499)
          error = parse(response.body)
          raise RemoteError.new(error['message'], response.status.to_s)
        else
          raise RemoteError.new("Unhandled error: STATUS=#{response.status} BODY=#{response.body}", response.status.to_s)
        end
      end

      def outlook_rest_url
        "https://outlook.office.com/api/v2.0/me"
      end

      private

        def get_access_token_object
          oauth_options = { :site => 'https://login.microsoftonline.com',
                            :authorize_url => '/common/oauth2/v2.0/authorize',
                            :token_url => '/common/oauth2/v2.0/token'
                          }
          oauth_configs = Integrations::OAUTH_CONFIG_HASH[APP_NAME]
          oauth_options = oauth_options.symbolize_keys
          client = OAuth2::Client.new(oauth_configs["consumer_token"], oauth_configs["consumer_secret"], oauth_options)
          token_hash = {
            :access_token => @service.sync_account.oauth_token,
            :refresh_token => @service.sync_account.refresh_token,
            :client_options => oauth_options,
            :header_format => {}
          }
          access_token = OAuth2::AccessToken.from_hash(client, token_hash)
        end

    end
  end
end
