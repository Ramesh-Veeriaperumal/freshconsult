class MemoizeMemcache
  def self.get_from_memoized_cache(key, raw)
    return unless id = RequestStore.store[:request_id] # Will return for web requests.

    @request_cache ||= {} # Will be nil when the class gets initialized for the first time.
    if @request_cache[id] # Will be nil for the first memcache call in the request.
    	@request_cache[id][key] || set_key(id, key, raw) # Will be nil for the first memcache call for that key.
    else
    	@request_cache = {} # request_cache will hold the data from the previous request, cleaning that up.
    	set_key(id, key, raw)
    end
  end

  def self.set_key(id, key, raw)
  	@request_cache[id] ||= {}
    @request_cache[id][key] = newrelic_begin_rescue { $memcache.get(key, raw) }
  end

  def self.delete_from_memoized_cache(key)
    return unless id = RequestStore.store[:request_id] # Will return for web requests.
    @request_cache[id].delete(key) if @request_cache && @request_cache[id].try(:[], key) # When memcache gets cleared during a request, have to reset the cache, in case it gets accessed during the same request.
  end

  def self.newrelic_begin_rescue(&block)
    begin
      block.call
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      return
    end 
  end
end