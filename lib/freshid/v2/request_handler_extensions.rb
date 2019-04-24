module Freshid::V2::RequestHandlerExtensions
    include Redis::RedisKeys
    include Redis::OthersRedis

    def get_client_credential_token_from_cache
      ###### Overridden ######
      $redis_others.perform_redis_op('get', FRESHID_V2_CLIENT_CREDS_TOKEN_KEY)
    end

    def cache_client_credential_token(token, key_expiry_time)
      ###### Overridden ######
      $redis_others.perform_redis_op('setex',  FRESHID_V2_CLIENT_CREDS_TOKEN_KEY, key_expiry_time, token)
    end

    def get_client_cred_with_domain_token_from_cache(org_domain = nil)
      ###### Overridden ######
      org_domain ||= Organisation.current.try(:domain)
      $redis_others.perform_redis_op('get', FRESHID_V2_ORG_CLIENT_CREDS_TOKEN_KEY % {organisation_domain: org_domain})
    end

    def cache_client_cred_with_domain_token(token, key_expiry_time, org_domain = nil)
      ###### Overridden ######
      org_domain ||= Organisation.current.try(:domain)
      $redis_others.perform_redis_op('setex',  FRESHID_V2_ORG_CLIENT_CREDS_TOKEN_KEY % {organisation_domain: org_domain}, key_expiry_time, token)
    end
end