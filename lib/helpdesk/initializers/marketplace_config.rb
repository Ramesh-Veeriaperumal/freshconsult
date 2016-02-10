module MarketplaceConfig

  config = YAML.load_file(File.join(Rails.root, 'config', 'marketplace.yml'))[Rails.env].symbolize_keys

  API_URL = config[:api_url]
  DEV_URL = config[:dev_portal_url]
  API_AUTH_KEY = config[:api_auth_key]
  DEV_OAUTH_KEY = config[:dev_oauth_key]
  DEV_OAUTH_SECRET = config[:dev_oauth_secret]
  ADMIN_OAUTH_KEY = config[:admin_oauth_key]
  ADMIN_OAUTH_SECRET = config[:admin_oauth_secret]
  S3_ASSETS = config[:s3_assets]
  S3_STATIC_ASSETS = config[:s3_static_assets]
  CDN_STATIC_ASSETS = config[:cdn_static_assets]
  CACHE_INVALIDATION_TIME = config[:cache_invalidation_time]
  API_TIMEOUT = config[:api_timeout]
end