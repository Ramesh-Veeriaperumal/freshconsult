module Cache::Memcache::Account

  include MemcacheKeys

  def ticket_types_from_cache
    key = ticket_types_memcache_key
    MemcacheKeys.fetch(key) { ticket_type_values }
  end

  def agents_from_cache
    key = agents_memcache_key
    MemcacheKeys.fetch(key) { self.agents.find(:all, :include => :user) }
  end

  def groups_from_cache
    key = groups_memcache_key
    MemcacheKeys.fetch(key) { self.groups.find(:all, :order=>'name' ) }
  end

  def tags_from_cache
    key = tags_memcache_key
    MemcacheKeys.fetch(key) { self.tags.all }
  end

  def customers_from_cache
    key = customers_memcache_key
    MemcacheKeys.fetch(key) { self.customers.all }
  end

  private
    def ticket_types_memcache_key
      ACCOUNT_TICKET_TYPES % { :account_id => self.id }
    end

    def agents_memcache_key
      ACCOUNT_AGENTS % { :account_id => self.id }
    end

    def groups_memcache_key
      ACCOUNT_GROUPS % { :account_id => self.id }
    end

    def tags_memcache_key
      ACCOUNT_TAGS % { :account_id => self.id }
    end

    def customers_memcache_key
      ACCOUNT_CUSTOMERS % { :account_id => self.id }
    end


end