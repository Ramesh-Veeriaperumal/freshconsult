require "memcache"

config = YAML::load_file(File.join(RAILS_ROOT, 'config', 'memcached.yml'))[RAILS_ENV]

$memcache = MemCache.new("#{config["servers"]}")
ActionController::Base.cache_store = :mem_cache_store, "#{config["servers"]}", config.delete("servers")