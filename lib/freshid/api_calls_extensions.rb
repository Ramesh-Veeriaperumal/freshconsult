module Freshid::ApiCallsExtensions
  def self.prepended(base)
    class << base
      prepend ClassMethods
    end  
  end

  module ClassMethods
    include Redis::RedisKeys
    include Redis::OthersRedis

    def get_client_credential_token_from_cache
      ###### Overridden ######
      $redis_others.perform_redis_op('get', FRESHID_CLIENT_CREDS_TOKEN_KEY)
    end

    def cache_client_credential_token(token, key_expiry_time)
      ###### Overridden ######
      $redis_others.perform_redis_op('setex', FRESHID_CLIENT_CREDS_TOKEN_KEY, key_expiry_time, token)
    end
  end
end
