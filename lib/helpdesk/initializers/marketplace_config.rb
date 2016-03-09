module MarketplaceConfig

  config = YAML.load_file(File.join(Rails.root, 'config', 'marketplace.yml'))[Rails.env].symbolize_keys

  API_URL = config[:api_url]
  ACC_API_URL = config[:acc_api_url]
  DEV_URL = config[:dev_portal_url]
  ADMIN_URL = config[:admin_url]
  API_AUTH_KEY = config[:api_auth_key]
  DEV_OAUTH_KEY = config[:dev_oauth_key]
  DEV_OAUTH_SECRET = config[:dev_oauth_secret]
  ADMIN_OAUTH_KEY = config[:admin_oauth_key]
  ADMIN_OAUTH_SECRET = config[:admin_oauth_secret]
  S3_ASSETS = config[:s3_assets]
  CDN_STATIC_ASSETS = config[:cdn_static_assets]
  CACHE_INVALIDATION_TIME = config[:cache_invalidation_time]
  ACC_API_TIMEOUT = { :read => config[:acc_api_read_timeout], :conn => config[:acc_api_conn_timeout] }
  GLOBAL_API_TIMEOUT = { :read => config[:global_api_read_timeout], :conn => config[:global_api_conn_timeout] }
  MKP_CB = FreshRequest::RedisUrlCb.new(
                max_failures: 5,
                trip_off_interval: 20,
                auto_on_after: 20,
                redis_client: $redis_integrations,
                namespace: "MKP_API"
              )
end