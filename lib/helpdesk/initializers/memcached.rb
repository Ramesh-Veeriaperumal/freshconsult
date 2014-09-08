config = YAML::load_file(File.join(Rails.root, 'config', 'memcached.yml'))[Rails.env].symbolize_keys!
servers = config.delete(:servers)
options = { :namespace => config[:namespace], :compress => true}
$memcache = Dalli::Client.new(servers, options)
ActionController::Base.cache_store = :mem_cache_store, servers, config


