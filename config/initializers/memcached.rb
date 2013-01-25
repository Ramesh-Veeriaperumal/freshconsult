require "memcache"
config = YAML::load_file(File.join(RAILS_ROOT, 'config', 'memcached.yml'))[RAILS_ENV]
servers = "#{config['servers']}".split(" ")
$memcache = MemCache.new servers, { :check_size =>  false, :timeout => 5 }
ActionController::Base.cache_store = :mem_cache_store, servers.join(","), config.delete("servers")
#ActionController::Base.cache_store = $memcache


