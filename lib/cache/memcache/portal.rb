module Cache::Memcache::Portal

  include MemcacheKeys

  module ClassMethods
    include MemcacheKeys
    def fetch_by_url(url)
      return if url.blank?
      key = PORTAL_BY_URL % { :portal_url => url }
      MemcacheKeys.fetch(key) { self.find(:first, :conditions => { :portal_url => url }) }
    end
  end

  def self.included(base)
    base.extend ClassMethods
  end

  def clear_portal_cache
    key = PORTAL_BY_URL % { :portal_url => @old_object.portal_url}
    MemcacheKeys.delete_from_cache key
    key = ACCOUNT_MAIN_PORTAL % { :account_id => @old_object.account_id }
    MemcacheKeys.delete_from_cache key
  end

end