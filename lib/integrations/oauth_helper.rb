module Integrations::OauthHelper

    def get_oauth2_access_token(provider, refresh_token, app_name)
      oauth_s = Integrations::OauthHelper.get_oauth_keys(provider, app_name)
      oauth_options = Integrations::OauthHelper.get_oauth_options(provider) || {}
      client = OAuth2::Client.new oauth_s["consumer_token"], oauth_s["consumer_secret"], oauth_options
      token_hash = { :refresh_token => refresh_token, :client_options => oauth_options, :header_format => header_format(app_name)}
      access_token = OAuth2::AccessToken.from_hash(client, token_hash)
      access_token.refresh! 
    end

    def get_oauth1_response(params)
      oauth_options = Integrations::OauthHelper.get_oauth_options(params[:app_name])
      oauth_options[:proxy] = "#{Integrations::PROXY_SERVER["protocol"]}://#{Integrations::PROXY_SERVER["host"]}:#{Integrations::PROXY_SERVER["port"]}" if !Rails.env.development? && Integrations::PROXY_SERVER["host"].present? #host will not be present for layers other than integration layer.
      oauth_keys = Integrations::OauthHelper.get_oauth_keys(params[:app_name])
      consumer = OAuth::Consumer.new(oauth_keys['consumer_token'], oauth_keys['consumer_secret'], oauth_options)
      installed_app = params[:installed_app] || Account.current.installed_applications.with_name(params[:app_name]).first
      access_token = OAuth::AccessToken.new(consumer, installed_app.configs[:inputs]["oauth_token"], installed_app.configs[:inputs]["oauth_token_secret"])
      return consumer.request(params[:method], params[:url], access_token, {}, params[:body], params[:headers])
    end

    def get_oauth_access_token(oauth_token, oauth_token_secret)
      oauth_s = Integrations::OauthHelper.get_oauth_keys('google')
      oauth_options = Integrations::OauthHelper.get_oauth_options('google')
      consumer = OAuth::Consumer.new(oauth_s["consumer_token"], oauth_s["consumer_secret"], oauth_options)
      # now create the access token object from passed values
      token_hash = { :oauth_token => oauth_token,
                     :oauth_token_secret => oauth_token_secret
                   }
      access_token = OAuth::AccessToken.from_hash(consumer, token_hash )
      return access_token
    end

    def auth_oauth2?(account, app_name, google_acc)
      installed_app = account.installed_applications.with_name(app_name).first
      unless installed_app[:configs].blank? #can nest it to the below block using &&
        unless installed_app[:configs][:inputs]["OAuth2"].blank?
          # No need to assign, last statement returns.
          value = installed_app[:configs][:inputs]["OAuth2"].include?("#{google_acc.email}") ? true : false
        else
          false
        end
      else
        false
      end
    end

    def self.get_oauth_options(provider)
      @config = File.join(Rails.root, 'config', 'oauth_config.yml')
      options_hash = (YAML::load_file @config)['oauth_options'][provider]      
      options_hash.symbolize_keys unless options_hash.blank?
    end

    def self.get_oauth_keys(provider = nil, app_name = nil)
      #### Fetch specific OAuth keys ####
      @config = File.join(Rails.root, 'config', 'oauth_config.yml')
      key_hash = (YAML::load_file @config)[Rails.env]

      if provider.blank?
        key_hash
      else
        if app_name.present? && key_hash[provider] && key_hash[provider]['app_options'].present?
          key_hash[provider]['options'] ||= {}
          key_hash[provider]['options'].merge!(key_hash[provider]['app_options'][app_name])
          key_hash[provider].delete('app_options')

          puts "key_hash: #{key_hash.inspect}\n"
        end
        key_hash[provider] 
      end
    end

    def header_format(app_name)
      return 'Bearer %s' if app_name=='surveymonkey'
      'OAuth %s'
    end
end
