module MarketplaceConfig

  config = YAML.load_file(File.join(Rails.root, 'config', 'marketplace.yml'))[Rails.env].symbolize_keys

  API_URL = config[:api_url]
  ACC_API_URL = config[:acc_api_url]
  DEV_URL = config[:dev_portal_url]
  ADMIN_URL = config[:admin_url]
  MKP_OAUTH_URL = config[:mkp_oauth_url]
  DATA_PIPE_URL = config[:data_pipe_url]
  DATA_PIPE_KEY = config[:data_pipe_key]
  API_AUTH_KEY = config[:api_auth_key]
  DEV_OAUTH_KEY = config[:dev_oauth_key]
  DEV_OAUTH_SECRET = config[:dev_oauth_secret]
  ADMIN_OAUTH_KEY = config[:admin_oauth_key]
  ADMIN_OAUTH_SECRET = config[:admin_oauth_secret]
  CDN_STATIC_ASSETS = config[:cdn_static_assets]
  CACHE_INVALIDATION_TIME = config[:cache_invalidation_time]
  CUSTOM_APPS_CACHE_INVD_TIME = config[:custom_apps_cache_invd_time]
  INTEGRATIONS_CACHE_INVD_TIME = config[:integrations_cache_invd_time]
  ACC_API_TIMEOUT = { :read => config[:acc_api_read_timeout], :conn => config[:acc_api_conn_timeout] }
  MKP_OAUTH_TIMEOUT = { :read => config[:mkp_oauth_read_timeout], :conn => config[:mkp_oauth_conn_timeout] }
  GLOBAL_API_TIMEOUT = { :read => config[:global_api_read_timeout], :conn => config[:global_api_conn_timeout] }
  DATA_PIPE_TIMEOUT = { :read => config[:data_pipe_timeout], :conn => config[:data_pipe_timeout] }
  FRESHAPPS_JS_URL = config[:freshapps_js_url]
  ACCOUNT_API_POLL_INTERVAL = config[:account_api_poll_interval]
  MKP_CB = FreshRequest::RedisUrlCb.new(
                max_failures: 5,
                trip_off_interval: 20,
                auto_on_after: 20,
                redis_client: $redis_integrations,
                namespace: "MKP_API"
              )
  DPROUTER_CB = FreshRequest::RedisUrlCb.new(
              max_failures: 5,
              trip_off_interval: 20,
              auto_on_after: 20,
              redis_client: $redis_integrations,
              namespace: "DP_ROUTER"
            )
end
