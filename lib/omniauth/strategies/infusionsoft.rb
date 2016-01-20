module OmniAuth
  module Strategies
    class Infusionsoft < OmniAuth::Strategies::OAuth2

      option :name, 'infusionsoft'

      option :client_options, {
        authorize_url: 'https://signin.infusionsoft.com/app/oauth/authorize',
        token_url:     'https://api.infusionsoft.com/token',
        site:          'https://signin.infusionsoft.com'
      }
     
    def full_host
     #The callback url contains the scope and authorization code.The scope contains a pipe character which needs to be removed.
     request_url = request.url.gsub(/scope.*\&/, '')
      case OmniAuth.config.full_host
      when String
        OmniAuth.config.full_host
      when Proc
        OmniAuth.config.full_host.call(env)
      else
        if request.scheme && request_url.match(URI::ABS_URI)
          uri = URI.parse(request_url.gsub(/\?.*$/, ''))
          uri.path = ''
          uri.scheme = 'https' if ssl?
          uri.to_s
        else ''
        end
      end
    end
    end
  end
end