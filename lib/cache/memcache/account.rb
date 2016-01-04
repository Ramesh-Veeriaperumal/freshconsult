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

  def custom_survey_from_cache
    key = ACCOUNT_CUSTOM_SURVEY % { :account_id => self.id }
    MemcacheKeys.fetch(key) do
      custom_surveys.active.first
    end
  end

  def ticket_types_from_cache
    key = ticket_types_memcache_key
    MemcacheKeys.fetch(key) { ticket_type_values.all }
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
    MemcacheKeys.fetch(key) { self.features.map(&:to_sym) }
  end

  def features_included?(*feature_names)
    feature_names.all? { |feature_name| feature_from_cache.include?(feature_name.to_sym) }
  end

  def companies_from_cache
    key = companies_memcache_key
    MemcacheKeys.fetch(key) { self.companies.all }
  end

  def twitter_handles_from_cache
    key = handles_memcache_key
    MemcacheKeys.fetch(key) { self.twitter_handles.all }
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
      ticket_fields_without_choices.custom_dropdown_fields.find(:all, :include => [:flexifield_def_entry,:level1_picklist_values] )
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
      ticket_field_def.flexifield_def_entries.event_fields.find(:all, :include => :ticket_field)
    end
  end

  def flexifields_with_ticket_fields_from_cache
    key = ACCOUNT_FLEXIFIELDS % { :account_id => self.id }
    MemcacheKeys.fetch(key) do
      ticket_field_def.flexifield_def_entries.find(:all, :include => :ticket_field)
    end
  end

  def ticket_fields_from_cache
    key = ACCOUNT_TICKET_FIELDS % { :account_id => self.id }
    MemcacheKeys.fetch(key) do
      ticket_fields_with_nested_fields.all
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

    # fetch won't know the difference between nils from query block and key not present.
    # Hence DB will be queried again & again via memcache for accounts without whitelisted ip if we use self.whitelisted_ip
    # Below query will return array containing results from query self.whitelisted_ip. 
    # So that cache won't be executed again & again for accounts without whitelistedip.
    MemcacheKeys.fetch(key) { WhitelistedIp.where(account_id: self.id).limit(1).all }
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
    MemcacheKeys.fetch(key) { self.forum_categories.find(:all, :include => [ :forums ]) }
  end

  def clear_forum_categories_from_cache
    key = FORUM_CATEGORIES % { :account_id => self.id }
    MemcacheKeys.delete_from_cache(key)
  end
  
  def solution_categories_from_cache
    MemcacheKeys.fetch(ALL_SOLUTION_CATEGORIES % { :account_id => self.id }) do
      #META-READ-HACK!!
      self.solution_categories.all(:conditions => {:is_default => false},:include => folder_scope_with_psc).collect do |cat|
        {
          :folders => cat.folders.map(&:as_cache),
          :portal_solution_categories => cat.portal_solution_categories.map(&:as_cache)
        }.merge(cat.as_cache).with_indifferent_access
      end
    end
  end

  def clear_solution_categories_from_cache
    key = ALL_SOLUTION_CATEGORIES % { :account_id => self.id }
    MemcacheKeys.delete_from_cache(key)
  end
  

  def sales_manager_from_cache
    if self.created_at > Time.now.utc - 3.days # Logic to handle sales manager change
      key = SALES_MANAGER_3_DAYS % { :account_id => self.id }
      expiry = 1.day.to_i
    else
      key = SALES_MANAGER_1_MONTH % { :account_id => self.id }
      expiry = 30.days.to_i
    end
    MemcacheKeys.fetch(key,expiry) do
      CRM::Salesforce.new.account_owner(self.id)
    end
  end

  def account_additional_settings_from_cache
    key = ACCOUNT_ADDITIONAL_SETTINGS % { :account_id => self.id }
    MemcacheKeys.fetch(key) { self.account_additional_settings }
  end

  def clear_account_additional_settings_from_cache
    key = ACCOUNT_ADDITIONAL_SETTINGS % { :account_id => self.id }
    MemcacheKeys.delete_from_cache(key)
  end

  def cti_installed_app_from_cache
    key = INSTALLED_CTI_APP % { :account_id => self.id }
    MemcacheKeys.fetch(key) do
      self.installed_applications.with_type_cti.first ? self.installed_applications.with_type_cti.first : false
    end
  end

  def clear_cti_installed_app_from_cache
    key = INSTALLED_CTI_APP % { :account_id => self.id }
    MemcacheKeys.delete_from_cache(key)
  end

  def ecommerce_reauth_check_from_cache
    key = ECOMMERCE_REAUTH_CHECK % {:account_id => self.id }
    MemcacheKeys.fetch(key) { self.ecommerce_accounts.reauth_required.present? }
  end

  def contact_password_policy_from_cache
    key = password_policy_memcache_key(PasswordPolicy::USER_TYPE[:contact])
    MemcacheKeys.fetch(key) { self.contact_password_policy }
  end

  def agent_password_policy_from_cache
    key = password_policy_memcache_key(PasswordPolicy::USER_TYPE[:agent])
    MemcacheKeys.fetch(key) { self.agent_password_policy }
  end

  def clear_contact_password_policy_from_cache
    key = password_policy_memcache_key(PasswordPolicy::USER_TYPE[:contact])
    MemcacheKeys.delete_from_cache(key)
  end

  def clear_agent_password_policy_from_cache
    key = password_policy_memcache_key(PasswordPolicy::USER_TYPE[:agent])
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

    def companies_memcache_key
      ACCOUNT_COMPANIES % { :account_id => self.id }
    end
    
    def handles_memcache_key
      ACCOUNT_TWITTER_HANDLES % { :account_id => self.id }
    end

    def password_policy_memcache_key(user_type)
      ACCOUNT_PASSWORD_POLICY % { :account_id => self.id, :user_type => user_type}
    end

    #META-READ-HACK!!
    def folder_scope_with_psc
       unless Account.current.present? && Account.current.launched?(:meta_read)
         return [:portal_solution_categories, :folders]
       end
       [ :portal_solution_categories_through_meta, :folders_through_meta ]
    end
    
end
