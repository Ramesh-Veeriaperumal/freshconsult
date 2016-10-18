class Search::RecentSearches < Search::RecentStore

  def initialize(recent_item=nil)
    @key = redis_persistent_recent_searches_key
    super
  end
  
  private

  def redis_persistent_recent_searches_key      
    PERSISTENT_RECENT_SEARCHES % { :account_id => Account.current.id, :user_id => User.current.id }
  end

end