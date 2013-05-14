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

    (@all_changes && @all_changes[:portal_url] || [] ).each do |url|
      key = PORTAL_BY_URL % { :portal_url => url}
      MemcacheKeys.delete_from_cache key
    end
    
    key = PORTAL_BY_URL % { :portal_url => @old_object.portal_url}
    MemcacheKeys.delete_from_cache key

    key = ACCOUNT_MAIN_PORTAL % { :account_id => @old_object.account_id }
    MemcacheKeys.delete_from_cache key
  end

  def fetch_template
    key = PORTAL_TEMPLATE % { :account_id => self.account_id, :portal_id => self.id }
    MemcacheKeys.fetch(key) { Portal::Template.find_by_portal_id(self.id) }
    # self.template
  end

end