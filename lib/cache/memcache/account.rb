module Cache::Memcache::Account

  include MemcacheKeys
  include Dashboard::Custom::CacheKeys

  module ClassMethods
    include MemcacheKeys
    def fetch_by_full_domain(full_domain)
      return if full_domain.blank?
      key = ACCOUNT_BY_FULL_DOMAIN % { :full_domain => full_domain }
      MemcacheKeys.fetch(key) { self.where(full_domain: full_domain).first }
    end
  end

  def self.included(base)
    base.extend ClassMethods
  end

  def dashboard_shard_from_cache
    key = ACCOUNT_DASHBOARD_SHARD_NAME % { :account_id => self.id }
    MemcacheKeys.fetch(key) {
      count = Search::Dashboard::Count.new(nil, self.id, nil)
      count.fetch_dashboard_shard
    }
  end

  def clear_cache
    key = ACCOUNT_BY_FULL_DOMAIN % { :full_domain => self.full_domain }
    MemcacheKeys.delete_from_cache key
    key = ACCOUNT_BY_FULL_DOMAIN % { :full_domain => @old_object.full_domain }
    MemcacheKeys.delete_from_cache key
  end

  def required_ticket_fields_from_cache
    @required_ticket_fields ||= begin
      if caching_enabled?
        key = ACCOUNT_REQUIRED_TICKET_FIELDS % { :account_id => self.id }
        MemcacheKeys.fetch(key) { self.required_ticket_fields.all }
      else
        self.required_ticket_fields.all
      end
    end
  end

  def section_parent_fields_from_cache
    @section_parent_fields ||= begin
      if caching_enabled?
        key = ACCOUNT_SECTION_PARENT_FIELDS % { :account_id => self.id }
        MemcacheKeys.fetch(key) { self.section_parent_fields.all }
      else
        self.section_parent_fields.all
      end
    end
  end

  def help_widget_from_cache(widget_id)
    key = HELP_WIDGETS % { :account_id => self.id, :id => widget_id }
    MemcacheKeys.fetch(key) { self.help_widgets.active.find_by_id(widget_id) }
  end

  def email_configs_from_cache
    @email_configs_from_cache ||= begin
      key = format(ACCOUNT_EMAIL_CONFIG, account_id: id)
      MemcacheKeys.fetch(key) { email_configs.all.each_with_object({}) { |e, map| map[e.id] = e.reply_email } }
    end
  end

  def clear_required_ticket_fields_cache
    key = ACCOUNT_REQUIRED_TICKET_FIELDS % { :account_id => self.id }
    MemcacheKeys.delete_from_cache(key)
  end

  def clear_section_parent_fields_cache
    key = ACCOUNT_SECTION_PARENT_FIELDS % { :account_id => self.id }
    MemcacheKeys.delete_from_cache(key)
  end

  def ticket_source_from_cache
    fetch_from_cache(ticket_source_memcache_key) { helpdesk_sources }
  end

  def clear_ticket_source_from_cache
    delete_value_from_cache(ticket_source_memcache_key)
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
      MemcacheKeys.fetch(key) { self.ticket_status_values.all }
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

  def active_custom_survey_choices
    active_custom_survey_from_cache.default_question.custom_field_choices
  end

  def ticket_types_from_cache
    key = ticket_types_memcache_key
    fetch_from_cache(key) { ticket_type_values.all }
  end

  def clear_ticket_types_from_cache
    delete_value_from_cache(ticket_types_memcache_key)
  end

  def agents_from_cache
    key = agents_memcache_key
    fetch_from_cache(key) { self.agents.includes([:user, :agent_groups]).all }
  end

  def custom_date_fields_from_cache
    @custom_date_fields_from_cache ||= begin
      key = custom_date_fields_memcache_key
      MemcacheKeys.fetch(key) { self.ticket_fields.where(field_type: 'custom_date').all }
    end
  end

  def clear_custom_date_fields_cache
    @custom_date_fields_from_cache = nil
    MemcacheKeys.delete_from_cache(custom_date_fields_memcache_key)
  end

  def custom_date_time_fields_from_cache
    @custom_date_time_fields_from_cache ||= begin
      key = custom_date_time_fields_memcache_key
      MemcacheKeys.fetch(key) { self.ticket_fields.where(field_type: 'custom_date_time').all }
    end
  end

  def clear_custom_date_time_fields_cache
    @custom_date_time_fields_from_cache = nil
    MemcacheKeys.delete_from_cache(custom_date_time_fields_memcache_key)
  end

  def custom_file_field_names_cache
    fetch_from_cache(custom_file_field_names_memcache_key) do
      ticket_fields.where(field_type: Helpdesk::TicketField::CUSTOM_FILE).pluck(:name)
    end
  end

  def clear_custom_file_field_names_cache
    delete_value_from_cache(custom_file_field_names_memcache_key)
  end

  def agents_hash_from_cache
    @agents_hash_from_cache ||= begin
      key = agent_hash_memcache_key
      MemcacheKeys.fetch(key) do
        agents_hash = {}
        Account.current.technicians.pluck_all('id', 'name', 'privileges', 'email').each do |agent|
          agents_hash[agent[0]] = [agent[1], agent[2], agent[3]]
        end
        agents_hash
      end
    end
  end

  def roles_from_cache
    @roles_from_cache ||= begin
      key = roles_cache_key
      MemcacheKeys.fetch(key) { self.roles.all }
    end
  end

  def agents_details_ar_from_cache
    key = agents_details_memcache_key
    fetch_from_cache(key) { users.where(helpdesk_agent: true).select('id,name,email,privileges').all }
  end

  def agents_details_optar_cache
    key = agents_details_optar_key
    fetch_from_cache(key) { users.technicians_basics }
  end

  def agents_details_from_cache
    agents_details_optar_cache
  end

  def groups_from_cache
    @groups_from_cache ||= begin
      key = groups_memcache_key
      MemcacheKeys.fetch(key) { self.groups.order('name').all }
    end
  end

  def support_agent_groups_from_cache
    @support_agent_groups_from_cache ||= begin
      key = support_agent_groups_memcache_key
      MemcacheKeys.fetch(key) { self.groups.support_agent_groups }
    end
  end

  def group_types_from_cache
    key = group_types_memcache_key
    fetch_from_cache(key) { group_types.all }
  end

  def clear_group_types_cache
    delete_value_from_cache(format(ACCOUNT_GROUP_TYPES, account_id: self.id))
  end

  def contribution_agent_groups_from_cache(user_id)
    key = contribution_agent_groups_memcache_key(user_id)
    fetch_from_cache(key) do
      contribution_agent_groups.where(user_id: user_id).all
    end
  end

  def agent_groups_from_cache
    @agent_groups_from_cache ||= begin
      key = agent_groups_optar_key
      MemcacheKeys.fetch(key) { agent_groups.basic_info }
    end
  end

  def agent_groups_hash_from_cache
    @agent_groups_hash_from_cache ||= begin
      key = agent_groups_hash_memcache_key
      MemcacheKeys.fetch(key) {
        Rails.logger.debug "fetching agent_groups from db"
        agent_groups_ids = Hash.new
        agents_groups = Account.current.agent_groups_from_cache
        agents_groups.each do |ag|
          agent_groups_ids[ag.group_id] ||= []
          agent_groups_ids[ag.group_id].push(ag.user_id)
        end
        agent_groups_ids
      }
    end
  end

  def write_access_agent_groups_hash_from_cache
    key = write_access_agent_groups_hash_memcache_key
    fetch_from_cache(key) do
      Rails.logger.debug 'fetching write_access_agent_groups from db'
      write_access_agent_groups.each_with_object({}) do |ag, agent_groups_ids|
        agent_groups_ids[ag.group_id] ||= []
        agent_groups_ids[ag.group_id].push(ag.user_id)
      end
    end
  end

  def products_optar_cache
    key = format(ACCOUNT_PRODUCTS_OPTAR, account_id: id)
    MemcacheKeys.fetch(key) { products.basic_info }
  end

  def products_ar_cache
    key = format(ACCOUNT_PRODUCTS, account_id: id)
    MemcacheKeys.fetch(key) { products.order('name').all }
  end

  def products_from_cache
    products_optar_cache
  end

  def tags_from_cache
    key = tags_optar_key
    MemcacheKeys.fetch(key) { tags.basic_info }
  end

  def feature_from_cache
    @feature_from_cache ||= begin
      key = FEATURES_LIST % { :account_id => self.id }
      MemcacheKeys.fetch(key) { self.features.map(&:to_sym) }
    end
  end

  def clear_feature_from_cache
    MemcacheKeys.delete_from_cache(FEATURES_LIST % { :account_id => self.id })
  end

  def reset_feature_from_cache_variable
    @feature_from_cache = nil
  end

  def features_included?(*feature_names)
    self.features? *feature_names.map(&:to_sym)
  end

  def companies_from_cache
    key = companies_optar_key
    MemcacheKeys.fetch(key) { companies.basic_info }
  end

  def default_calendar_from_cache
    @default_calendar_from_cache ||= begin
      key = DEFAULT_BUSINESS_CALENDAR % {:account_id => self.id}
      MemcacheKeys.fetch(key) do
        self.business_calendar.default.first
      end
    end
  end

  def twitter_handles_from_cache
    key = handles_memcache_key
    fetch_from_cache(key) { self.twitter_handles.all }
  end

  def twitter_reauth_check_from_cache
    key = TWITTER_REAUTH_CHECK % {:account_id => self.id }
    MemcacheKeys.fetch(key) { self.twitter_handles.reauth_required.present? }
  end

  def fb_reauth_check_from_cache
    key = FB_REAUTH_CHECK % {:account_id => self.id }
    MemcacheKeys.fetch(key) { self.facebook_pages.reauth_required.present? }
  end

  def check_mailbox_oauth_status
    if features_included?('mailbox')
      key = format(OAUTH_MAILBOX_STATUS_CHECK, account_id: id)
      MemcacheKeys.fetch(key) { imap_mailboxes.oauth_errors.present? || smtp_mailboxes.oauth_errors.present? }
    end
  end

  def fb_realtime_msg_from_cache
    key = FB_REALTIME_MSG_ENABLED % {:account_id => self.id }
    MemcacheKeys.fetch(key) { self.facebook_pages.realtime_messaging_disabled.present? }
  end

  def custom_dropdown_fields_from_cache
    @custom_dropdown_fields_from_cache ||= begin
      key = ACCOUNT_CUSTOM_DROPDOWN_FIELDS % { :account_id => self.id }
      MemcacheKeys.fetch(key) do
        ticket_fields_without_choices.custom_dropdown_fields.includes([:flexifield_def_entry,:level1_picklist_values]).all
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
    key = format(ACCOUNT_EVENT_FIELDS, account_id: id)
    fetch_from_cache(key) do
      ticket_field_def.flexifield_def_entries.event_fields.includes(:ticket_field).all
    end
  end

  def flexifields_with_ticket_fields_from_cache
    key = ACCOUNT_FLEXIFIELDS % { :account_id => self.id }
    fetch_from_cache(key) do
      ticket_field_def.flexifield_def_entries.with_active_ticket_field.preload(:ticket_field).all
    end
  end

  def ticket_fields_name_type_mapping_cache
    fetch_from_cache(ticket_fields_name_type_mapping_key(id)) do
      ticket_fields_with_nested_fields.all.select { |field| field.default == false }.map { |x| [x.name, x.field_type] }.to_h
    end
  end

  def ticket_fields_from_cache
    @ticket_fields_from_cache ||= begin
      key = format(ACCOUNT_TICKET_FIELDS, account_id: id)
      MemcacheKeys.fetch(key) do
        ticket_fields_with_nested_fields.all
      end
    end
  end

  def all_ticket_fields_with_nested_fields_from_cache
    key = format(ACCOUNT_TICKET_FIELDS_WITH_ARCHIVED_FIELDS, account_id: id)
    fetch_from_cache(key) { all_ticket_fields_with_nested_fields.all }
  end

  def nested_ticket_fields_from_cache
    key = ACCOUNT_NESTED_TICKET_FIELDS % { :account_id => self.id }
    MemcacheKeys.fetch(key) do
      nested_ticket_fields_with_childs.all
    end
  end

  def section_fields_with_field_values_mapping_cache
    if Account.current.archive_ticket_fields_enabled?
      key = format(ACCOUNT_SECTION_FIELDS_WITHOUT_ARCHIVED_FIELDS, account_id: id)
      fetch_from_cache(key) { section_fields_without_archived_fields.all }
    else
      key = format(ACCOUNT_SECTION_FIELDS_WITH_FIELD_VALUE_MAPPING, account_id: id)
      fetch_from_cache(key) { section_fields_with_field_values_mapping.all }
    end
  end

  # Ex:  {11=>{"ticket_type"=>["Incident", "Lead", "Question"]}, 12=>{"ticket_type"=>["Question"]}, 31=>{"ticket_type"=>["Question"]}}
  def section_field_parent_field_mapping_from_cache
    @section_field_parent_field_mapping_from_cache ||= begin
      key = format(ACCOUNT_SECTION_FIELD_PARENT_FIELD_MAPPING, account_id: id)
      MemcacheKeys.fetch(key) do
        parent_field_value_mapping.each_with_object({}) do |(k, v), inverse|
          v.each do |e|
            inverse[e] = (inverse[e] || {}).merge(k) { |i, o, n| o + n }
          end
        end
      end
    end
  end

  def skills_trimmed_version_from_cache
    @skills_trimmed_version_from_cache ||= begin
      key = ACCOUNT_SKILLS_TRIMMED % { :account_id => self.id }
      MemcacheKeys.fetch(key) do
        sorted_skills.trimmed.all
      end
    end
  end

  def skills_from_cache
    @skills_from_cache ||= begin
      key = ACCOUNT_SKILLS % { :account_id => self.id }
      MemcacheKeys.fetch(key) do
        skills.all
      end
    end
  end

  def reset_skills_trimmed_version_from_cache
    @skills_trimmed_version_from_cache = nil
  end

  def reset_skills_from_cache
    @skills_from_cache = nil
  end

  def scheduled_ticket_exports_from_cache
    @scheduled_ticket_exports_from_cache ||= begin
      key = ACCOUNT_SCHEDULED_TICKET_EXPORTS % { :account_id => self.id }
      MemcacheKeys.fetch(key) do
        self.scheduled_ticket_exports.all
      end
    end
  end

  def activity_export_from_cache
    @activity_export_from_cache ||= begin
      key = ACCOUNT_ACTIVITY_EXPORT % { :account_id => self.id }
      MemcacheKeys.fetch(key) do
        self.activity_export
      end
    end
  end

  def observer_rules_from_cache
    key = ACCOUNT_OBSERVER_RULES % { :account_id => self.id }
    MemcacheKeys.fetch(key) do
      observer_rules.all
    end
  end

  def service_task_observer_rules_from_cache
    key = ACCOUNT_SERVICE_TASK_OBSERVER_RULES % { account_id: self.id }
    fetch_from_cache(key) { self.service_task_observer_rules.all }
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
    key = format(ACCOUNT_AGENT_NAMES, account_id: self.id)
    fetch_from_cache(key) do
      users.where(helpdesk_agent: 1).pluck(:name)
    end
  end

  def api_webhooks_rules_from_cache
    key = format(ACCOUNT_API_WEBHOOKS_RULES, account_id: self.id)
    fetch_from_cache(key) { api_webhook_rules.all }
  end

  def installed_app_business_rules_from_cache
    key = ACCOUNT_INSTALLED_APP_BUSINESS_RULES % { :account_id => self.id }
    MemcacheKeys.fetch(key) do
      installed_app_business_rules.all
    end
  end

  def forum_categories_from_cache
    key = FORUM_CATEGORIES % { :account_id => self.id }
    MemcacheKeys.fetch(key) { self.forum_categories.includes([:forums]).all }
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
      # CRM::Salesforce.new.account_owner(self.id)
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
    fetch_from_cache(key) { self.account_additional_settings }
  end

  def account_status_groups_from_cache
    @account_status_groups_from_cache ||= begin
      key = ACCOUNT_STATUS_GROUPS % {:account_id => self.id}
      MemcacheKeys.fetch(key) { self.status_groups.order(:group_id).all }
    end
  end

  def clear_account_additional_settings_from_cache
    key = ACCOUNT_ADDITIONAL_SETTINGS % { :account_id => self.id }
    delete_value_from_cache(key)
  end

  def cti_installed_app_from_cache
    @cti_installed_app_from_cache ||= begin
      key = INSTALLED_CTI_APP % { :account_id => self.id }
      MemcacheKeys.fetch(key) do
        self.installed_applications.with_type_cti.first ? self.installed_applications.with_type_cti.first : false
      end
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
    key = permissible_domains_optar_key
    MemcacheKeys.fetch(key) { helpdesk_permissible_domains.basic_info }
  end

  def clear_helpdesk_permissible_domains_from_cache
    MemcacheKeys.delete_from_cache(permissible_domains_memcache_key(Account.current.id))
    MemcacheKeys.delete_from_cache(permissible_domains_optar_key(Account.current.id))
  end

  def contact_password_policy_from_cache
    key = password_policy_memcache_key(PasswordPolicy::USER_TYPE[:contact])
    fetch_from_cache(key) { self.contact_password_policy }
  end

  def agent_password_policy_from_cache
    key = password_policy_memcache_key(PasswordPolicy::USER_TYPE[:agent])
    fetch_from_cache(key) { self.agent_password_policy }
  end

  def latest_trial_subscription_from_cache
    key = TRIAL_SUBSCRIPTION % { :account_id => self.id }
    MemcacheKeys.fetch(key) { self.trial_subscriptions.last }
  end

  def clear_contact_password_policy_from_cache
    key = password_policy_memcache_key(PasswordPolicy::USER_TYPE[:contact])
    delete_value_from_cache(key)
  end

  def clear_agent_password_policy_from_cache
    key = password_policy_memcache_key(PasswordPolicy::USER_TYPE[:agent])
    delete_value_from_cache(key)
  end


  def clear_requester_widget_fields_from_cache
    key = REQUESTER_WIDGET_FIELDS % { :account_id => current_account.id }
    MemcacheKeys.delete_from_cache key
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
    MemcacheKeys.delete_from_cache(key)
  end

  def clear_account_status_groups_cache
    key = ACCOUNT_STATUS_GROUPS % {:account_id => self.id}
    MemcacheKeys.delete_from_cache(key)
  end

  def clear_requester_widget_fields_from_cache
    key = REQUESTER_WIDGET_FIELDS % { :account_id => current_account.id }
    MemcacheKeys.delete_from_cache key
  end

  def clear_dashboards_cache
    self.dashboards.each do |dashboard|
      MemcacheKeys.delete_from_cache(dashboard_cache_key(dashboard.id))
    end
  end

  def bots_count_from_cache
    @bots_count_from_cache ||= begin
      MemcacheKeys.fetch(bots_count_memcache_key) { bots.count }
    end
  end

  def bots_from_cache
    @bots_from_cache ||= begin
      MemcacheKeys.fetch(bots_memcache_key) { bots_hash }
    end
  end

  def clear_bots_from_cache
    MemcacheKeys.delete_from_cache(bots_memcache_key)
  end

  def clear_bots_count_from_cache
    MemcacheKeys.delete_from_cache(bots_count_memcache_key)
  end

  def canned_responses_inline_images_from_cache
    @canned_responses_inline_images_from_cache ||= begin
      MemcacheKeys.fetch(canned_responses_inline_images_key) do
        Account.current.canned_responses_inline_images
      end
    end
  end

  def clear_canned_responses_inline_images_from_cache
    MemcacheKeys.delete_from_cache(canned_responses_inline_images_key)
  end

  def contact_filters_from_cache
    @contact_filters_from_cache ||= begin
      key = format(CONTACT_FILTERS, account_id: id)
      MemcacheKeys.fetch(key) do
        contact_filters.all
      end
    end
  end

  def clear_contact_filters_cache
    key = format(CONTACT_FILTERS, account_id: id)
    MemcacheKeys.delete_from_cache(key)
  end

  def company_filters_from_cache
    @company_filters_from_cache ||= begin
      key = format(COMPANY_FILTERS, account_id: id)
      MemcacheKeys.fetch(key) do
        company_filters.all
      end
    end
  end

  def agent_types_from_cache
    key = agent_type_memcache_key(self.id)
    fetch_from_cache(key) { agent_types.all }
  end

  def clear_agent_types_cache
    key = agent_type_memcache_key(self.id)
    delete_value_from_cache(key)
  end

  def clear_company_filters_cache
    key = format(COMPANY_FILTERS, account_id: id)
    MemcacheKeys.delete_from_cache(key)
  end

  def installed_apps_from_cache
    @installed_apps ||= begin
      MemcacheKeys.fetch(installed_apps_key) do
        installed_apps_hash
      end
    end
  end

  def clear_installed_application_hash_cache
    key = installed_apps_key
    MemcacheKeys.delete_from_cache(key)
  end

  def unassociated_categories_from_cache
    MemcacheKeys.fetch(unassociated_categories_memcache_key) do
      associated_category_ids = Account.current.portal_solution_categories.pluck(:solution_category_meta_id).uniq
      Account.current.solution_category_meta.where('id NOT IN (?)', associated_category_ids).pluck(:id)
    end
  end

  def clear_unassociated_categories_cache
    MemcacheKeys.delete_from_cache(unassociated_categories_memcache_key)
  end

  def custom_nested_field_choices_hash_from_cache
    fetch_from_cache(custom_nested_field_choices_hash_key(id)) do
      nested_fields_from_cache.collect { |x| [x.name, x.formatted_nested_choices] }.to_h
    end
  end

  def picklist_values_by_id_cache
    @picklist_values_by_id_cache ||= MemcacheKeys.get_multi_from_cache(dropdown_nested_fields.map(&:picklist_values_by_id_key))
  end

  def picklist_ids_by_value_cache
    @picklist_ids_by_value_cache ||= MemcacheKeys.get_multi_from_cache(dropdown_nested_fields.map(&:picklist_ids_by_value_key))
  end

  def observer_condition_fields_from_cache
    key = format(OBSERVER_CONDITION_FIELDS, account_id: id)
    fetch_from_cache(key) do
      custom_ticket_field_names = ticket_fields_name_type_mapping_cache.each_with_object([]) do |field, arr|
        arr.push(field[0]) unless Va::Constants::OBSERVER_TEXT_CUSTOM_FIELD_TYPES.include?(field[1])
      end
      observer_rules.each_with_object([]) do |rule, fields|
        rule.rule_conditions.each do |condition|
          if observer_field_check(fields, custom_ticket_field_names, condition[:name])
            fields.push(condition[:name])
            if condition[:related_conditions].present?
              condition[:related_conditions].each do |related|
                fields.push(related[:name]) if observer_field_check(fields, custom_ticket_field_names, related[:name])
              end
            end
          end
          if condition[:associated_fields].present? &&
             observer_field_check(fields, custom_ticket_field_names, condition[:associated_fields][:name])
            fields.push(condition[:associated_fields][:name])
          end
        end
      end
    end
  end

  private
    def observer_field_check(fields, custom_ticket_field_names, field_name)
      !fields.include?(field_name) &&
        (Va::Constants::OBSERVER_CONDITION_FIELD_NAMES.include?(field_name) ||
        custom_ticket_field_names.include?(field_name))
    end

    def permissible_domains_memcache_key id = self.id
      HELPDESK_PERMISSIBLE_DOMAINS % { :account_id => id }
    end

    def permissible_domains_optar_key(account_id = id)
      format(HELPDESK_PERMISSIBLE_DOMAINS_OPTAR, account_id: account_id)
    end

    def unassociated_categories_memcache_key
      UNASSOCIATED_CATEGORIES % { account_id: Account.current.id }
    end

    def ticket_types_memcache_key
      ACCOUNT_TICKET_TYPES % { :account_id => self.id }
    end

    def agents_memcache_key
      ACCOUNT_AGENTS % { :account_id => self.id }
    end

    def custom_date_fields_memcache_key
      format(ACCOUNT_CUSTOM_DATE_FIELDS, account_id: self.id)
    end

    def custom_date_time_fields_memcache_key
      format(ACCOUNT_CUSTOM_DATE_TIME_FIELDS, account_id: self.id)
    end

    def custom_file_field_names_memcache_key
      format(ACCOUNT_CUSTOM_FILE_FIELD_NAMES, account_id: id)
    end

    def agent_hash_memcache_key
      format(ACCOUNT_AGENTS_HASH, account_id: id)
    end

    def roles_cache_key
      ACCOUNT_ROLES % { :account_id => self.id }
    end

    def agents_details_memcache_key
      ACCOUNT_AGENTS_DETAILS % { :account_id => self.id }
    end

    def agents_details_optar_key
      format(ACCOUNT_AGENTS_DETAILS_OPTAR, account_id: id)
    end

    def installed_apps_key
      format(INSTALLED_APPS_HASH, account_id: id)
    end

    def groups_memcache_key
      ACCOUNT_GROUPS % { :account_id => self.id }
    end

    def support_agent_groups_memcache_key
      ACCOUNT_SUPPORT_AGENT_GROUPS % { :account_id => self.id }
    end

    def agent_groups_memcache_key
      ACCOUNT_AGENT_GROUPS % { account_id: id }
    end

    def agent_groups_optar_key
      format(ACCOUNT_AGENT_GROUPS_OPTAR, account_id: id)
    end

    def agent_groups_hash_memcache_key
      ACCOUNT_AGENT_GROUPS_HASH % { account_id: id }
    end

    def write_access_agent_groups_hash_memcache_key
      format(ACCOUNT_WRITE_ACCESS_AGENT_GROUPS_HASH, account_id: id)
    end

    def tags_memcache_key
      ACCOUNT_TAGS % { :account_id => self.id }
    end

    def tags_optar_key
      format(ACCOUNT_TAGS_OPTAR, account_id: id)
    end

    def companies_memcache_key
      ACCOUNT_COMPANIES % { :account_id => self.id }
    end

    def companies_optar_key
      format(ACCOUNT_COMPANIES_OPTAR, account_id: id)
    end

    def handles_memcache_key
      ACCOUNT_TWITTER_HANDLES % { :account_id => self.id }
    end

    def password_policy_memcache_key(user_type)
      ACCOUNT_PASSWORD_POLICY % { :account_id => self.id, :user_type => user_type}
    end

    def ticket_source_memcache_key
      format(ACCOUNT_SOURCES, account_id: id)
    end

    def bots_memcache_key
      ACCOUNT_BOTS % { account_id: self.id }
    end

    def group_types_memcache_key
      ACCOUNT_GROUP_TYPES % { :account_id => self.id }
    end

    def bots_count_memcache_key
      BOTS_COUNT % { account_id: self.id }
    end

    def agent_type_memcache_key(account_id)
      ACCOUNT_AGENT_TYPES % { :account_id => account_id }
    end

    def canned_responses_inline_images_key
      CANNED_RESPONSES_INLINE_IMAGES % { account_id: self.id }
    end

    def ticket_fields_name_type_mapping_key(account_id)
      format(ACCOUNT_TICKET_FIELDS_NAME_TYPE_MAPPING, account_id: account_id)
    end

    def custom_nested_field_choices_hash_key(account_id)
      format(CUSTOM_NESTED_FIELD_CHOICES, account_id: account_id)
    end

    def contribution_agent_groups_memcache_key(user_id = nil)
      format(AGENT_CONTRIBUTION_ACCESS_GROUPS, account_id: id, user_id: user_id)
    end

    def sources
      if Account.current.compose_email_enabled?
        Account.current.helpdesk_sources.ticket_source_keys_by_token.values | [Account.current.helpdesk_sources.ticket_source_keys_by_token[:outbound_email]]
      else
        Account.current.helpdesk_sources.ticket_source_keys_by_token.values
      end
    end

    # Ex: [[{"ticket_type"=>["Question", "Feature Request"]}, [11, 12, 13]], [{"ticket_type"=>["Problem"]}, [11]]]
    def parent_field_value_mapping
      sections_fields_group_by_parent_field_value_mapping.map { |parent_grouping, fields| [parent_grouping, fields.map(&:ticket_field_id)] }
    end

    def sections_fields_group_by_parent_field_value_mapping
      section_fields_with_field_values_mapping_cache.group_by do |x|
        { x.parent_ticket_field.name => x.section.section_picklist_mappings.map { |y| y.picklist_value.value } }
      end
    end
end