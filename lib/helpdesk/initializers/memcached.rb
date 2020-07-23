memcacheserializer = Marshal

ENV['TIME_BANDITS_VERBOSE'] = 'true' if Rails.env.development? # logging is enabled and default for development env
# Logs GC and Heap stats for each request
TimeBandits.add ::TimeBandits::TimeConsumers::GarbageCollection.instance if ENV['TIME_BANDITS_VERBOSE']
TimeBandits.add ::TimeBandits::TimeConsumers::CustomDalli # logging custom_dalli performance time for Controller caching

# The below config is used for caching the app data. (Groups, Agent, TicketFields)
config = YAML.load_file(Rails.root.join('config', 'dalli.yml'))[Rails.env].symbolize_keys!
servers = config.delete(:servers)
options = {
  namespace: config[:namespace],
  compress: config[:compress],
  socket_max_failures: config[:socket_max_failures],
  socket_timeout: config[:socket_timeout],
  serializer: memcacheserializer,
  failover: config[:failover],
  down_retry_delay: config[:down_retry_delay]
}
$memcache = Dalli::Client.new(servers, options)

# The below config is used for controller caching(page, action, fragment) offered by rails
custom_config = YAML.load_file(Rails.root.join('config', 'custom_dalli.yml'))[Rails.env].symbolize_keys!
custom_servers = custom_config.delete(:servers)
ActionController::Base.cache_store = :dalli_store, custom_servers, custom_config
custom_options = {
  namespace: custom_config[:namespace],
  compress: custom_config[:compress],
  socket_max_failures: custom_config[:socket_max_failures],
  socket_timeout: custom_config[:socket_timeout],
  failover: custom_config[:failover],
  down_retry_delay: custom_config[:down_retry_delay]
}
$custom_memcache = Dalli::Client.new(custom_servers, custom_options)
