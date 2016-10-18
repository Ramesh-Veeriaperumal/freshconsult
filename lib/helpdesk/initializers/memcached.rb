# The below config is used for caching the app data. (Groups, Agent, TicketFields)
config = YAML::load_file(File.join(Rails.root, 'config', 'dalli.yml'))[Rails.env].symbolize_keys!
servers = config.delete(:servers)
options = { :namespace => config[:namespace], :compress => config[:compress], :socket_max_failures => config[:socket_max_failures], :socket_timeout => config[:socket_timeout] }
$memcache = Dalli::Client.new(servers, options)

# The below config is used for controller caching(page, action, fragment) offered by rails
custom_config = YAML::load_file(File.join(Rails.root, 'config', 'custom_dalli.yml'))[Rails.env].symbolize_keys!
custom_servers = custom_config.delete(:servers)
ActionController::Base.cache_store = :dalli_store, custom_servers, custom_config

