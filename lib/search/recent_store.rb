class Search::RecentStore

  include Redis::RedisKeys
  include Redis::OthersRedis  

  MIN_RECENTS = 0
  MAX_RECENTS = 4

  #15 Day Persistence
  REDIS_TTL = 1296000

  def initialize(recent_item=nil)    
    @member = recent_item
  end


  def recent      
  # Get Recent Searches from Redis
    get_members_others_sorted_set_range @key, MIN_RECENTS, MAX_RECENTS  
  end

  def delete
    remove_member_others_sorted_set @key, @member   
  end

  def store
    add_member_to_others_sorted_set @key, Time.now.to_f, @member, REDIS_TTL
    remove_members_others_sorted_set_rank @key, 0, -6 
  end  
end