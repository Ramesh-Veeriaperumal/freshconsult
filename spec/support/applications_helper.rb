require 'spec_helper'

module ApplicationsHelper

	def redis_key(provider)
		key_options = { :account_id => RSpec.configuration.account.id, :provider => provider}
    Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options)
	end

	def set_redis_key(provider, config_params)		
		key_spec = redis_key(provider)
		kv_store = Redis::KeyValueStore.new(key_spec, config_params, {:group => :integration, :expire => 300})
    kv_store.set_key
	end

	def get_redis_key(provider)
		key_spec = redis_key(provider)			
    kv_store = Redis::KeyValueStore.new(key_spec)
    kv_store.group = :integration
    kv_store.get_key
	end

	def surveymonkey_params(provider)
		"{\"app_name\":\"#{provider}\", 
			\"oauth_token\":\"5f21246b-78d7-4b48-a700-edc3b70185f7\", 
      \"uid\":\"sample@freshdesk.com\"}"
	end

	def salesforce_params(provider)
		"{\"app_name\":\"#{provider}\", 
			\"oauth_token\":\"00DE0000000aCv7!\", 
      \"uid\":\"sample@freshdesk.com\",
      \"instance_url\":\"https://ap1.salesforce.com\" }"
	end

end