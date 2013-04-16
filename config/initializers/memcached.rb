require "memcache"
config = YAML::load_file(File.join(RAILS_ROOT, 'config', 'memcached.yml'))[RAILS_ENV].symbolize_keys!
servers = config.delete(:servers)
$memcache = MemCache.new servers, { :check_size =>  false, :timeout => 5, :no_reply => true }
ActionController::Base.cache_store = :mem_cache_store, servers, config
#ActionController::Base.cache_store = $memcache


