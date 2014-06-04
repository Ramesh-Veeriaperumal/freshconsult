module Cache::Memcache::Account

  include MemcacheKeys
  module ClassMethods
    include MemcacheKeys
    def fetch_by_full_domain(full_domain)
      return if full_domain.blank?
      key = ACCOUNT_BY_FULL_DOMAIN % { :full_domain => full_domain }
      MemcacheKeys.fetch(key) { self.find(:first, :conditions => { :full_domain => full_domain }) }
    end
  end

  def self.included(base)
    base.extend ClassMethods
  end

  def clear_cache
    key = ACCOUNT_BY_FULL_DOMAIN % { :full_domain => self.full_domain }
    MemcacheKeys.delete_from_cache key
    key = ACCOUNT_BY_FULL_DOMAIN % { :full_domain => @old_object.full_domain }
    MemcacheKeys.delete_from_cache key
  end

  def clear_api_limit_cache
    key = API_LIMIT % {:account_id => self.id }
    MemcacheKeys.delete_from_cache key
  end

  def main_portal_from_cache
    key = ACCOUNT_MAIN_PORTAL % { :account_id => self.id }
    MemcacheKeys.fetch(key) { self.main_portal }
  end

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

  def products_from_cache
    key = ACCOUNT_PRODUCTS % { :account_id => self.id }
    MemcacheKeys.fetch(key) { self.products.find(:all, :order => 'name') }
  end

  def tags_from_cache
    key = tags_memcache_key
    MemcacheKeys.fetch(key) { self.tags.all }
  end

  def feature_from_cache
    key = FEATURES_LIST % { :account_id => self.id }
    MemcacheKeys.fetch(key) { self.features }
  end

  def features_included?(*feature_names)
    feature_names.all? { |feature_name| feature_from_cache.send("#{feature_name}?") }
  end

  def customers_from_cache
    key = customers_memcache_key
    MemcacheKeys.fetch(key) { self.customers.all }
  end

  def twitter_handles_from_cache
    key = handles_memcache_key
    MemcacheKeys.fetch(key) { self.twitter_handles }
  end
  
  def twitter_reauth_check_from_cache
    key = TWITTER_REAUTH_CHECK % {:account_id => self.id }
    MemcacheKeys.fetch(key) { self.twitter_handles.reauth_required.present? }
  end

  def fb_reauth_check_from_cache
    key = FB_REAUTH_CHECK % {:account_id => self.id }
    MemcacheKeys.fetch(key) { self.facebook_pages.reauth_required.present? }
  end

  def custom_dropdown_fields_from_cache
    key = ACCOUNT_CUSTOM_DROPDOWN_FIELDS % { :account_id => self.id }
    MemcacheKeys.fetch(key) do
      ticket_fields.custom_dropdown_fields.find(:all, :include => :flexifield_def_entry )
    end
  end

  def nested_fields_from_cache
    key = ACCOUNT_NESTED_FIELDS % { :account_id => self.id }
    MemcacheKeys.fetch(key) do
      ticket_fields.nested_fields.find(:all, :include => [:nested_ticket_fields, :flexifield_def_entry] )
    end
  end

  def event_flexifields_with_ticket_fields_from_cache
    key = ACCOUNT_EVENT_FIELDS % { :account_id => self.id }
    MemcacheKeys.fetch(key) do
      flexifield_def_entries.event_fields.find(:all, :include => :ticket_field)
    end
  end

  def flexifields_with_ticket_fields_from_cache
    key = ACCOUNT_FLEXIFIELDS % { :account_id => self.id }
    MemcacheKeys.fetch(key) do
      flexifield_def_entries.find(:all, :include => :ticket_field)
    end
  end

  def observer_rules_from_cache
    key = ACCOUNT_OBSERVER_RULES % { :account_id => self.id }
    MemcacheKeys.fetch(key) do
      observer_rules.find(:all)
    end
  end

   def whitelisted_ip_from_cache
    key = WHITELISTED_IP_FIELDS % { :account_id => self.id }
    MemcacheKeys.fetch(key) { self.whitelisted_ip }
  end

  def agent_names_from_cache
    key = ACCOUNT_AGENT_NAMES % { :account_id => self.id }
    MemcacheKeys.fetch(key) do
      users.find(:all, :conditions => { :helpdesk_agent => 1 }).map(&:name)
    end
  end

  def api_webhooks_rules_from_cache
    key = ACCOUNT_API_WEBHOOKS_RULES % { :account_id => self.id }
    MemcacheKeys.fetch(key) do
      api_webhook_rules.find(:all)
    end
  end

  def forum_categories_from_cache
    key = FORUM_CATEGORIES % { :account_id => self.id }
    MemcacheKeys.fetch(key) { self.forum_categories.find(:all, :include => [ :forums ], :order => :position) }
  end

  def clear_forum_categories_from_cache
    key = FORUM_CATEGORIES % { :account_id => self.id }
    MemcacheKeys.delete_from_cache(key)
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
    
    def handles_memcache_key
      ACCOUNT_TWITTER_HANDLES % { :account_id => self.id }
    end


end
