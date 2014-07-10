module Cache::Memcache::Portal::Template

  include MemcacheKeys

  def clear_memcache_cache
    key = PORTAL_TEMPLATE % { :account_id => self.account_id, :portal_id => self.portal_id }
    MemcacheKeys.delete_from_cache key
  end

  def fetch_page_by_type type
    key = PORTAL_TEMPLATE_PAGE % { :account_id => self.account_id, :template_id => self.id, 
      :page_type => type }
    MemcacheKeys.fetch(key) { self.pages.find_by_page_type( type ) || false }
  end

end