require "memcache"
config = YAML::load_file(File.join(Rails.root, 'config', 'memcached.yml'))[Rails.env].symbolize_keys!
servers = config.delete(:servers)
#$memcache = MemCache.new servers, { :check_size =>  false, :timeout => 5, :no_reply => true}
options = { :namespace => config[:namespace], :compress => true}
$memcache = Dalli::Client.new(servers, options)
ActionController::Base.cache_store = :mem_cache_store, servers, config
#ActionController::Base.cache_store = $memcache


