config = YAML::load_file(File.join(Rails.root, 'config', 'dalli.yml'))[Rails.env].symbolize_keys!
servers = config.delete(:servers)
options = { :namespace => config[:namespace], :compress => config[:compress], :socket_max_failures => config[:socket_max_failures], :socket_timeout => config[:socket_timeout] }
$memcache = Dalli::Client.new(servers, options)
ActionController::Base.cache_store = :dalli_store, servers, config

