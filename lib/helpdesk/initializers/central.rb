include Redis::RedisKeys
central_config = YAML.load(File.read("#{Rails.root}/config/central.yml"))[Rails.env]
CENTRAL_SECRET_CONFIG = central_config['central_secret']
CentralPublisher.configure do |config|
  config.central_url = central_config["api_endpoint"]
  config.service_token = central_config["service_token"]
  config.redis_store = $redis_others
  config.redis_key = PROCESSING_FAILED_CENTRAL_FEEDS
end