module Cache::Memcache::Helpdesk::Filters::CustomTicketFilter

  include MemcacheKeys

  def clear_cache
    account.agents.each do |agent|
      key = user_filters_memcache_key(agent.user,account)
      MemcacheKeys.delete_from_cache(key)
    end
  end

  def my_ticket_filters(user)
    key = self.user_filters_memcache_key(user)
    MemcacheKeys.fetch(key) { self.find(:all, :joins =>"JOIN admin_user_accesses acc ON acc.account_id =  wf_filters.account_id AND acc.accessible_id = wf_filters.id AND acc.accessible_type = 'Wf::Filter' LEFT JOIN agent_groups ON acc.group_id=agent_groups.group_id", :order => 'created_at desc', :conditions =>["acc.VISIBILITY=#{Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]} OR agent_groups.user_id=#{user.id} OR (acc.VISIBILITY=#{Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]} and acc.user_id=#{user.id})"]) }
  end

  def user_filters_memcache_key(user,account=Account.current)
    USER_TICKET_FILTERS % { :account_id => account.id,:user_id => user.id }
  end
  
end