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

  def onhold_and_closed_statuses_from_cache
    @onhold_and_closed_statuses_from_cache ||= begin
      key = ACCOUNT_ONHOLD_CLOSED_STATUSES % { :account_id => self.id}
      MemcacheKeys.fetch(key) { Helpdesk::TicketStatus.onhold_and_closed_statuses(self) }
    end
  end

  def ticket_status_values_from_cache
    @ticket_status_values_from_cache ||= begin
      key = ACCOUNT_STATUSES % { :account_id => self.id }
      MemcacheKeys.fetch(key) { self.ticket_status_values.find(:all) }
    end
  end
  
  def clear_api_limit_cache
    key = API_LIMIT % {:account_id => self.id }
    MemcacheKeys.delete_from_cache key
  end

  def main_portal_from_cache
    @main_portal_from_cache ||= begin
      key = ACCOUNT_MAIN_PORTAL % { :account_id => self.id }
      MemcacheKeys.fetch(key) { self.main_portal }
    end
  end

  def active_custom_survey_from_cache
    @active_custom_survey_from_cache ||= begin
      key = ACCOUNT_CUSTOM_SURVEY % { :account_id => self.id }
      MemcacheKeys.fetch(key) do
        custom_surveys.active.with_questions_and_choices.first
      end
    end
  end

  def ticket_types_from_cache
    @ticket_types_from_cache ||= begin
      key = ticket_types_memcache_key
      MemcacheKeys.fetch(key) { ticket_type_values.all }
    end
  end

  def agents_from_cache
    @agents_from_cache ||= begin
      key = agents_memcache_key
      MemcacheKeys.fetch(key) { self.agents.find(:all, :include => [:user,:agent_groups]) }
    end
  end

  def roles_from_cache
    @roles_from_cache ||= begin
      key = roles_cache_key
      MemcacheKeys.fetch(key) { self.roles.find(:all) }
    end
  end

  def agents_details_from_cache
    key = agents_details_memcache_key
    MemcacheKeys.fetch(key) { self.users.where(:helpdesk_agent => true).select("id,name,email").all }
  end  

  def groups_from_cache
    @groups_from_cache ||= begin
      key = groups_memcache_key
      MemcacheKeys.fetch(key) { self.groups.find(:all, :order=>'name' ) }
    end
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
    @feature_from_cache ||= begin
      key = FEATURES_LIST % { :account_id => self.id }
      MemcacheKeys.fetch(key) { self.features.map(&:to_sym) }
    end
  end

  def reset_feature_from_cache_variable
    @feature_from_cache = nil
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
    @custom_dropdown_fields_from_cache ||= begin
      key = ACCOUNT_CUSTOM_DROPDOWN_FIELDS % { :account_id => self.id }
      MemcacheKeys.fetch(key) do
        ticket_fields_without_choices.custom_dropdown_fields.find(:all, :include => [:flexifield_def_entry,:level1_picklist_values] )
      end
    end
  end

  def nested_fields_from_cache
    @nested_fields_from_cache ||= begin
      key = ACCOUNT_NESTED_FIELDS % { :account_id => self.id }
      MemcacheKeys.fetch(key) do
        ticket_fields_including_nested_fields.nested_fields.all
      end
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


  def section_fields_with_field_values_mapping_cache
    key = ACCOUNT_SECTION_FIELDS_WITH_FIELD_VALUE_MAPPING % { account_id: self.id }
    MemcacheKeys.fetch(key) do
      section_fields_with_field_values_mapping.all
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
      api_webhook_rules.all
    end
  end

  def installed_app_business_rules_from_cache
    key = ACCOUNT_INSTALLED_APP_BUSINESS_RULES % { :account_id => self.id }
    MemcacheKeys.fetch(key) do
      installed_app_business_rules.all
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
      self.solution_category_meta.all(:conditions => {:is_default => false},
          :include => [:primary_category,{ :solution_folder_meta => [:primary_folder]}, :portal_solution_categories]).collect do |c_meta|
        {
          :folders => c_meta.solution_folder_meta.map(&:as_cache),
          :portal_solution_categories => c_meta.portal_solution_categories.map(&:as_cache)
        }.merge(c_meta.as_cache).with_indifferent_access
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

  def fresh_sales_manager_from_cache
    if self.created_at > Time.now.utc - 3.days # Logic to handle sales manager change
      key = FRESH_SALES_MANAGER_3_DAYS % { :account_id => self.id }
      expiry = 1.day.to_i
    else
      key = FRESH_SALES_MANAGER_1_MONTH % { :account_id => self.id }
      expiry = 30.days.to_i
    end
    MemcacheKeys.fetch(key,expiry) do
      begin
        CRM::FreshsalesUtility.new({ account: self }).account_manager  
      rescue  => e
        CRM::FreshsalesUtility::DEFAULT_ACCOUNT_MANAGER
      end      
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

  def helpdesk_permissible_domains_from_cache
    MemcacheKeys.fetch(permissible_domains_memcache_key) { self.helpdesk_permissible_domains.select(:domain).all }
  end

  def clear_helpdesk_permissible_domains_from_cache
    MemcacheKeys.delete_from_cache(permissible_domains_memcache_key(Account.current.id))
  end

  def contact_password_policy_from_cache
    @contact_password_policy_from_cache ||= begin
      key = password_policy_memcache_key(PasswordPolicy::USER_TYPE[:contact])
      MemcacheKeys.fetch(key) { self.contact_password_policy }
    end
  end

  def agent_password_policy_from_cache
    @agent_password_policy_from_cache ||= begin
      key = password_policy_memcache_key(PasswordPolicy::USER_TYPE[:agent])
      MemcacheKeys.fetch(key) { self.agent_password_policy }
    end
  end

  def clear_contact_password_policy_from_cache
    key = password_policy_memcache_key(PasswordPolicy::USER_TYPE[:contact])
    MemcacheKeys.delete_from_cache(key)
  end

  def clear_agent_password_policy_from_cache
    key = password_policy_memcache_key(PasswordPolicy::USER_TYPE[:agent])
    MemcacheKeys.delete_from_cache(key)
  end

  def installed_apps_in_company_page_from_cache
    key = ACCOUNT_INSTALLED_APPS_IN_COMPANY_PAGE % { :account_id => self.id }
    MemcacheKeys.fetch(key) do
      condition = "applications.dip & #{2**Integrations::Constants::DISPLAY_IN_PAGES['company_show']} > 0"
      self.installed_applications.includes(:application).where(condition)
    end
  end

  def clear_application_on_dip_from_cache
    key = ACCOUNT_INSTALLED_APPS_IN_COMPANY_PAGE % { :account_id => self.id }
    MemcacheKeys.delete_from_cache key
  end

  private
    def permissible_domains_memcache_key id = self.id
      HELPDESK_PERMISSIBLE_DOMAINS % { :account_id => id }
    end

    def ticket_types_memcache_key
      ACCOUNT_TICKET_TYPES % { :account_id => self.id }
    end

    def agents_memcache_key
      ACCOUNT_AGENTS % { :account_id => self.id }
    end

    def roles_cache_key
      ACCOUNT_ROLES % { :account_id => self.id }
    end

    def agents_details_memcache_key
      ACCOUNT_AGENTS_DETAILS % { :account_id => self.id }
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
end
