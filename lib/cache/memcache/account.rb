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

  def tags_from_cache
    key = tags_memcache_key
    MemcacheKeys.fetch(key) { self.tags.all }
  end

  def customers_from_cache
    key = customers_memcache_key
    MemcacheKeys.fetch(key) { self.customers.all }
  end

  def custom_dropdown_fields_from_cache
    key = ACCOUNT_CUSTOM_DROPDOWN_FIELDS % { :account_id => self.id }
    MemcacheKeys.fetch(key) do
      ticket_fields.custom_dropdown_fields(:include => {:flexifield_def_entry => {:include => :flexifield_picklist_vals } } ).find(:all)
    end
  end

  def nested_fields_from_cache
    key = ACCOUNT_NESTED_FIELDS % { :account_id => self.id }
    MemcacheKeys.fetch(key) do
      ticket_fields.nested_fields(:include => {:flexifield_def_entry => {:include => :flexifield_picklist_vals } } ).find(:all)
    end
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