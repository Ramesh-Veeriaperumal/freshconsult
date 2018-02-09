include Redis::RedisKeys
central_config = YAML.load(ERB.new(File.read("#{Rails.root}/config/central.yml")).result)[Rails.env]
CentralPublisher.configure do |config|
  config.central_url = central_config["api_endpoint"]
  config.service_token = central_config["service_token"]
  config.redis_store = $redis_others
  config.redis_key = PROCESSING_FAILED_CENTRAL_FEEDS
end
