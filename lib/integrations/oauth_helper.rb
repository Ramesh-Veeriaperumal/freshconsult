module Integrations::OauthHelper

  	def get_oauth2_access_token(provider, refresh_token, app_name)
      oauth_s = Integrations::OauthHelper.get_oauth_keys(provider, app_name)
      oauth_options = Integrations::OauthHelper.get_oauth_options(provider) || {}
      client = OAuth2::Client.new oauth_s["consumer_token"], oauth_s["consumer_secret"], oauth_options
      token_hash = { :refresh_token => refresh_token, :client_options => oauth_options, :header_format => header_format(app_name)}
      access_token = OAuth2::AccessToken.from_hash(client, token_hash)
      access_token.refresh! 
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

    def self.get_oauth_options(provider)
      @config = File.join(Rails.root, 'config', 'oauth_config.yml')
      options_hash = (YAML::load_file @config)['oauth_options'][provider]      
      options_hash.symbolize_keys unless options_hash.blank?
    end

    def self.get_oauth_keys(provider = nil, app_name = nil)
      #### Fetch specific OAuth keys ####
      @config = File.join(Rails.root, 'config', 'oauth_config.yml')
      key_hash = (YAML::load_file @config)[Rails.env]

      #### Facebook OAuth Keys ####
      config = File.join(Rails.root, 'config', 'facebook.yml')
      tokens = (YAML::load_file config)[Rails.env]
      consumer_key = tokens['app_id']
      consumer_secret = tokens['secret_key']
      key_hash[:facebook] = {}
      key_hash[:facebook] = {"consumer_token" => consumer_key, "consumer_secret" => consumer_secret}
      #key_hash.merge({:facebook => {:consumer_key => consumer_key, :consumer_secret => consumer_secret}})

      #### Twitter OAuth Keys ####
      config = File.join(Rails.root, 'config', 'twitter.yml')
      tokens = (YAML::load_file config)
      consumer_key = tokens['consumer_token'][Rails.env]
      consumer_secret = tokens['consumer_secret'][Rails.env]
      key_hash[:twitter] = {}
      key_hash[:twitter] = {"consumer_token" => consumer_key, "consumer_secret" => consumer_secret}

      if provider.blank?
        key_hash
      else
        if app_name.present? and key_hash[provider]['app_options'].present?
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