module Social::Ext::AgentMethods
  
  include Redis::RedisKeys
  include Social::Constants
  
  def add_social_search(search_hash)
    newrelic_begin_rescue do
      $redis_others.perform_redis_op("zadd", stream_redis_key, Time.now.to_i, search_hash.to_json)
      length = $redis_others.perform_redis_op("zcard", stream_redis_key)
      $redis_others.perform_redis_op("zremrangebyrank", stream_redis_key, 0, 0) if length > RECENT_SEARCHES_COUNT # Remove the element at the index 0      
    end
  end
  
  def recent_social_searches
    searches = []
    recent_searches = []
    newrelic_begin_rescue { searches = $redis_others.perform_redis_op("zrevrangebyscore", stream_redis_key, "+inf", "-inf") }
    unless searches.blank? 
      search_terms = searches.map {|search| JSON.parse(search)} 
      search_terms.each  do |term_hash|
        recent_searches << term_hash.each { |key,value| term_hash[key] = [""] if value.nil? }
      end
    end
    recent_searches
  end
  
  def clear_social_searches
    newrelic_begin_rescue { $redis_others.perform_redis_op("del", stream_redis_key) }
  end
  
  private
    def stream_redis_key
      STREAM_RECENT_SEARCHES % { :account_id => Account.current.id, :agent_id => self.id }
    end 
end
