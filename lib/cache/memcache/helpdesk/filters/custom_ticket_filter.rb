module Cache::Memcache::Helpdesk::Filters::CustomTicketFilter

  include MemcacheKeys

  def clear_cache
    key = Helpdesk::Filters::CustomTicketFilter.user_filters_memcache_key
    MemcacheKeys.delete_from_cache(key)
  end

  def my_ticket_filters(user)
    key = self.user_filters_memcache_key
    MemcacheKeys.fetch(key) { self.find(:all, :joins =>"JOIN admin_user_accesses acc ON acc.account_id =  wf_filters.account_id AND acc.accessible_id = wf_filters.id AND acc.accessible_type = 'Wf::Filter' LEFT JOIN agent_groups ON acc.group_id=agent_groups.group_id", :order => 'created_at desc', :conditions =>["acc.VISIBILITY=#{Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]} OR agent_groups.user_id=#{user.id} OR (acc.VISIBILITY=#{Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]} and acc.user_id=#{user.id})"]) }
  end

  def user_filters_memcache_key
    USER_TICKET_FILTERS % { :account_id => Account.current.id,:user_id => User.current.id }
  end
  
end