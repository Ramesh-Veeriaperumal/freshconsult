class Account < ActiveRecord::Base

  self.primary_key = :id
  
  include Mobile::Actions::Account
  include Social::Ext::AccountMethods
  include Cache::Memcache::Account
  include Redis::RedisKeys
  include Redis::TicketsRedis
  include Redis::OthersRedis
  include Redis::DisplayIdRedis
  include Redis::OthersRedis
  include ErrorHandle
  include AccountConstants
  include Helpdesk::SharedOwnershipMigrationMethods
  include Onboarding::OnboardingRedisMethods
  include FreshdeskFeatures::Feature
  include Helpdesk::SharedOwnershipMigrationMethods

  has_many_attachments
  
  serialize :sso_options, Hash

  pod_filter "id"
  
  is_a_launch_target
  
  concerned_with :associations, :constants, :validations, :callbacks, :features, :solution_associations, :multilingual

  include CustomerDeprecationMethods
  
  xss_sanitize  :only => [:name,:helpdesk_name], :plain_sanitizer => [:name,:helpdesk_name]
  
  attr_accessible :name, :domain, :user, :plan, :plan_start, :creditcard, :address,
                  :logo_attributes,:fav_icon_attributes,:ticket_display_id,:google_domain ,
                  :language, :ssl_enabled, :whitelisted_ip_attributes, :account_additional_settings_attributes,
                  :primary_email_config_attributes, :main_portal_attributes

  attr_accessor :user, :plan, :plan_start, :creditcard, :address, :affiliate

  include Account::Setup
  include Account::BackgroundFixtures

  scope :active_accounts,
              :conditions => [" subscriptions.state != 'suspended' "], 
              :joins => [:subscription]

  scope :trial_accounts,
              :conditions => [" subscriptions.state = 'trial' "], 
              :joins => [:subscription]

  scope :free_accounts,
              :conditions => [" subscriptions.state IN ('free','active') and subscriptions.amount = 0 "], 
              :joins => [:subscription]

  scope :paid_accounts,
              :conditions => [" subscriptions.state = 'active' and subscriptions.amount > 0 "], 
              :joins => [:subscription]

  scope :premium_accounts, {:conditions => {:premium => true}}
              
  scope :non_premium_accounts, {:conditions => {:premium => false}}

  Limits = {
    'agent_limit' => Proc.new {|a| a.full_time_agents.count }
  }
  
  Limits.each do |name, meth|
    define_method("reached_#{name}?") do
      return false unless self.subscription
      self.subscription.safe_send(name) && self.subscription.safe_send(name) <= meth.call(self)
    end
  end

  has_features do
    PLANS_AND_FEATURES.each_pair do |k, v|
      feature k, :requires => ( v[:inherits] || [] )
      v[:features].each { |f_n| feature f_n, :requires => [] } unless v[:features].nil?
      (SELECTABLE_FEATURES.keys + TEMPORARY_FEATURES.keys + 
        ADMIN_CUSTOMER_PORTAL_FEATURES.keys).each { |f_n| feature f_n }
    end
  end

  def node_feature_list
    @node_feature_list ||= begin
      feature_list = []
      FD_NODE_FEATURES.each do |ns|
        feature_list << ns if features?(ns)
      end
      feature_list
    end
  end

  def time_zone
    tz = self.read_attribute(:time_zone)
    tz = "Kyiv" if tz.eql?("Kyev")
    tz
  end

  def survey
    @survey ||= begin
      if new_survey_enabled?
        active_custom_survey_from_cache || custom_surveys.first
      else
        surveys.first unless surveys.blank?
      end
    end
  end

  def ticket_custom_dropdown_nested_fields
    @ticket_custom_dropdown_nested_fields ||= begin
      ticket_fields_from_cache.select{|x| x.default == false && (x.field_type == 'nested_field' || x.field_type == 'custom_dropdown')}
    end
  end
  
  # Feature check to prevent data from being sent to v1 conditionally
  # V1 has been completely removed in production
  def esv1_enabled?
    false
    # (ES_ENABLED && launched?(:es_v1_enabled))
  end

  def permissible_domains
    helpdesk_permissible_domains.pluck(:domain).join(",")
  end

  def permissible_domains=(list)
    self.helpdesk_permissible_domains_attributes = CustomNestedAttributes.new(list, self).helpdesk_permissible_domains_attributes if list.present?
  end

  def master_queries?
    ismember?(MASTER_QUERIES, self.id)
  end

  def public_ticket_token
    self.secret_keys[:public_ticket_token]
  end

  def attachment_secret
    self.secret_keys[:attachment_secret]
  end

  #Temporary feature check methods - using redis keys - ends here

  def round_robin_capping_enabled?
    features?(:round_robin_load_balancing)
  end

  def validate_required_ticket_fields?
    ismember?(VALIDATE_REQUIRED_TICKET_FIELDS, self.id)
  end

  def freshfone_active?
    features?(:freshfone) && freshfone_numbers.present? && !falcon_ui_enabled?(User.current)
  end
  
  def es_multilang_soln?
    features_included?(:es_multilang_solutions) || launched?(:es_multilang_solutions)
  end

  def active_groups
    active_groups_in_account(id)
  end

  def has_any_scheduled_ticket_export?
    auto_ticket_export_enabled? && scheduled_ticket_exports_from_cache.present?
  end

  def fields_with_in_operators
    custom_dropdown = "custom_dropdown"
    default_in_op_fields = Hash.new

    default_in_op_fields[:ticket] = DEFAULT_IN_OPERATOR_FIELDS[:ticket].clone
    default_in_op_fields[:ticket] << custom_dropdown_fields_from_cache.map(&:name)
    default_in_op_fields[:ticket].flatten!

    default_in_op_fields[:requester] = DEFAULT_IN_OPERATOR_FIELDS[:requester].clone
    default_in_op_fields[:requester] << contact_form.custom_fields.custom_dropdown_fields.pluck(:name)
    default_in_op_fields[:requester].flatten!

    default_in_op_fields[:company] = DEFAULT_IN_OPERATOR_FIELDS[:company].clone
    default_in_op_fields[:company] << company_form.custom_fields.custom_dropdown_fields.pluck(:name)
    default_in_op_fields[:company].flatten!

    default_in_op_fields.stringify_keys!
  end

  class << self # class methods

    def reset_current_account
      Thread.current[:account] = nil
    end

    def actual_customer_count
      Account.count('id',:distinct => true,:joins => :subscription_payments)
    end

    def current
      Thread.current[:account]
    end

    def fetch_all_active_accounts
      results = Sharding.run_on_all_shards do
        Account.find(:all,:joins => :subscription, :conditions => "subscriptions.next_renewal_at > now()")
      end
    end

    protected :fetch_all_active_accounts
  end
  
  def installed_apps_hash
    installed_apps = self.installed_applications.includes(:application).all
    installed_apps.inject({}) do |result,installed_app|
     result[installed_app.application.name.to_sym] = installed_app
     result
   end
  end
  
  def can_add_agents?(agent_count)
    subscription.agent_limit.nil? or 
      (subscription.agent_limit >= (agent_count + full_time_agents.count))
  end

  def agent_limit_reached?(agent_limit)
    agent_limit && agents_from_cache.find_all { |a| a.occasional == false && a.user.deleted == false }.count >= agent_limit
  end
  
  def get_max_display_id
    ticket_dis_id = self.ticket_display_id
    max_dis_id = self.tickets.maximum('display_id')
    unless max_dis_id.nil?
      return  ticket_dis_id > max_dis_id ? ticket_dis_id : max_dis_id+1
    end
    return 1
  end

  def max_display_id
    return get_max_display_id unless self.features?(:redis_display_id)
    
    key = TICKET_DISPLAY_ID % { :account_id => self.id }
    get_display_id_redis_key(key).to_i
  end

  
  def account_managers
    technicians.select do |user|
      user.privilege?(:manage_account)
    end
  end
  
  def needs_payment_info?
    if new_record?
      AppConfig['require_payment_info_for_trials'] && @plan && @plan.amount.to_f + @plan.setup_amount.to_f > 0
    else
      self.subscription.needs_payment_info?
    end
  end
  
  # Does the account qualify for a particular subscription plan
  # based on the plan's limits
  def qualifies_for?(plan)
    Subscription::Limits.keys.collect {|rule| rule.call(self, plan) }.all?
  end
  
  def active?
    self.subscription && !self.subscription.suspended?
  end

  def spam_email?
    ismember?(SPAM_EMAIL_ACCOUNTS, self.id)
  end

  def premium_email?
    ismember?(PREMIUM_EMAIL_ACCOUNTS, self.id)
  end

  def premium_gamification_account?
    ismember?(PREMIUM_GAMIFICATION_ACCOUNT, self.id)
  end

  def plan_name
    subscription.subscription_plan.canon_name
  end
  
  def domain
    @domain ||= self.full_domain.blank? ? '' : self.full_domain.split('.').first
  end
  
  def domain=(domain)
    @domain = domain
    self.full_domain = "#{domain}.#{AppConfig['base_domain'][Rails.env]}"
  end
  
  def default_friendly_email
    primary_email_config.active? ? primary_email_config.friendly_email : "support@#{full_domain}"
  end

  def default_friendly_email_personalize(user_name)
    primary_email_config.active? ? 
      primary_email_config.friendly_email_personalize(user_name) :
      "#{primary_email_config.safe_send(:format_name, user_name)} <support@#{full_domain}>"
  end
  
  def default_email
    primary_email_config.reply_email
  end
  
  def to_s
    name.blank? ? full_domain : "#{name} (#{full_domain})"
  end
  
  #Will be used as :host in emails
  def host
    main_portal_from_cache.portal_url.blank? ? full_domain : main_portal_from_cache.portal_url
  end
  
  def full_url
    "#{url_protocol}://#{host}"
  end

  def url_protocol
    self.ssl_enabled? ? 'https' : 'http'
  end
  
  #Helpdesk hack starts here
  def reply_emails
    to_ret = (email_configs.collect { |ec| [ec.id, ec.friendly_email] }).sort
    to_ret.empty? ? [[ nil, "support@#{full_domain}" ]] : to_ret #to_email case will come, when none of the emails are active.. 
  end
  #HD hack ends..

  #Helpdesk hack starts here
  def reply_personalize_emails(user_name)
    to_ret = (email_configs.collect { |ec| [ec.id, ec.friendly_email_personalize(user_name)] }).sort
    to_ret.empty? ? [[ nil, "support@#{full_domain}" ]] : to_ret #to_email case will come, when none of the emails are active.. 
  end
  #HD hack ends..
  
  def support_emails
    to_ret = email_configs.collect { |ec| ec.reply_email }
    to_ret.empty? ? [ "support@#{full_domain}" ] : to_ret #to_email case will come, when none of the emails are active.. 
  end

  def support_emails_in_downcase
    to_ret = email_configs.collect(&:reply_email_in_downcase)
    to_ret.empty? ? [ "support@#{full_domain}" ] : to_ret 
  end

  def portal_name #by Shan temp.
    main_portal.name
  end
  
   def language
    main_portal.language
   end
  
  #Sentient things start here, can move to lib some time later - Shan
  def make_current
    Thread.current[:account] = self
  end
  #Sentient ends here

  def add_features_of(s_plan)
    p_features = PLANS_AND_FEATURES[s_plan]
    unless p_features.nil?
      p_features[:inherits].each { |p_n| add_features_of(p_n) } unless p_features[:inherits].nil?

      p_features[:features].each { |f_n| features.safe_send(f_n).create } unless p_features[:features].nil?
    end
  end
  
  def remove_features_of(s_plan)
    p_features = PLANS_AND_FEATURES[s_plan]
    unless p_features.nil?
      p_features[:inherits].each { |p_n| remove_features_of(p_n) } unless p_features[:inherits].nil?
      
      p_features[:features].each { |f_n| features.safe_send(f_n).destroy } unless p_features[:features].nil?
    end
  end

  def add_features(feature_list)
    features.build(*feature_list)
  end

  def remove_feature(feature)
    features.safe_send(feature).destroy
  end
  
  def ticket_type_values
    ticket_fields_without_choices.type_field.first.level1_picklist_values
  end
  
  def ticket_status_values
    ticket_statuses.visible
  end

  def has_multiple_products?
    !products.empty?
  end

  def has_multiple_portals?
    @multiple_portals = portals.count > 1 if @multiple_portals.nil?
    @multiple_portals
  end
  
  def kbase_email
    "kbase@#{full_domain}"
  end
  
  def has_credit_card?
    !subscription.card_number.nil?
  end

  #Totally removed 
  def google_account?
    !google_domain.blank?
  end

  def date_type(format)
    DATEFORMATS_TYPES[DATEFORMATS[self.account_additional_settings.date_format]][format]
  end
  
  def default_form
    ticket_field_def
  end
  
  def is_saml_sso?
    self.sso_options.key? :sso_type and self.sso_options[:sso_type] == SsoUtil::SAML;
  end

  def sso_login_url
    if self.is_saml_sso?
      self.sso_options[:saml_login_url]
    else
      self.sso_options[:login_url]
    end
  end

  #Simplified login and logout url helper methods for saml and simple SSO.
  def sso_logout_url
    if self.is_saml_sso?
      self.sso_options[:saml_logout_url]
    else
      self.sso_options[:logout_url]
    end
  end

  def reset_sso_options
    self.sso_options = set_sso_options_hash
  end

  def enable_ticket_archiving(archive_days = 120)
    add_features(:archive_tickets)
    if account_additional_settings.additional_settings.present?
      account_additional_settings.additional_settings[:archive_days] = archive_days
      account_additional_settings.save
    else
      additional_settings = { :archive_days => archive_days }
      account_additional_settings.update_attributes(:additional_settings => additional_settings)
    end
  end

  def portal_languages
    account_additional_settings.additional_settings[:portal_languages]
  end

  def verified?
    self.reputation > 0
  end

  def verify_account_with_email
    unless verified?
      self.reputation = 1
      if self.save
        Rails.logger.info "Account Verification Completed account_id: #{self.id} signup_method: #{self.signup_method}"
      end
    end
  end

  def onboarding_pending?
    account_onboarding_pending?
  end

  def marketplace_app_enabled?
    features?(:marketplace_app)
  end

  def skip_dispatcher?
    marketplace_app_enabled? && launched?(:synchronous_apps)
  end

  def remove_secondary_companies
    user_companies.find_each do |user_company|
      user_company.destroy unless user_company.default
    end
  end

  def add_new_facebook_page?
    self.features?(:facebook) || (self.basic_facebook_enabled? &&
      self.facebook_pages.count == 0)
  end
  
  def advanced_twitter?
    features? :twitter
  end

  def add_twitter_handle?
    basic_twitter_enabled? and (advanced_twitter? or twitter_handles.count == 0)
  end

  def add_custom_twitter_stream?
    advanced_twitter?
  end

  def twitter_feature_present?
    basic_twitter_enabled? || advanced_twitter?
  end

  def ehawk_reputation_score
    if self.conversion_metric
      self.conversion_metric.spam_score
    else
      begin
        key = ACCOUNT_SIGN_UP_PARAMS % {:account_id => self.id}
        signup_params_json = get_others_redis_key(key)
        return 0 unless signup_params_json
        signup_params = JSON.parse(signup_params_json)
        signup_params["api_response"]["status"]   
      rescue Exception => e
        Rails.logger.debug "Exception caught #{e}"
        0
      end
    end
  end

  def ehawk_spam?
    ehawk_reputation_score >= 4
  end

  def dashboard_shard_name
    dashboard_shard_from_cache.presence || ActiveRecord::Base.current_shard_selection.shard.to_s
  end

  def update_ticket_dynamo_shard
    acct_addtn_settings = self.account_additional_settings
    if acct_addtn_settings
      if acct_addtn_settings.additional_settings.present?
        acct_addtn_settings.additional_settings[:tkt_dynamo_shard] = Helpdesk::Ticket::TICKET_DYNAMO_NEXT_SHARD
      else
        addtn_settings = {
          :tkt_dynamo_shard => Helpdesk::Ticket::TICKET_DYNAMO_NEXT_SHARD
        }
        acct_addtn_settings.additional_settings = addtn_settings
      end
      acct_addtn_settings.save
    end
  end

  def copy_right_enabled?
    subscription.sprout_plan? || subscription.trial? || (branding_enabled?)
  end

  def account_activation_job_status_key
    ACCOUNT_ADMIN_ACTIVATION_JOB_ID % {:account_id => self.id}
  end

  def schedule_account_activation_email(admin_user_id)
    # Storing job id in redis key which will be used update_domain to delete job,
    # when user completes the signup. 
    set_others_redis_key(account_activation_job_status_key,
      SendSignupActivationMail.perform_in(10.minutes.from_now,{ :user_id => admin_user_id, :account_id => self.id }))
  end

  def kill_account_activation_email_job
    job_id = get_others_redis_key(account_activation_job_status_key)
    job = Sidekiq::ScheduledSet.new.find_job(job_id)
    job.delete if job.present?
    delete_account_activation_job_status
  end

  def delete_account_activation_job_status
    remove_others_redis_key(account_activation_job_status_key)
  end

  # This method is used to update version of available entities which is consumed in falcon.
  def versionize_timestamp
    begin
      entity_keys = get_others_redis_hash(version_key).keys
      return if entity_keys.blank?
      hash_set = Hash[entity_keys.collect { |key| [key, Time.now.utc.to_i] }]
      set_others_redis_hash(version_key, hash_set)
    rescue Exception => e
      Rails.logger.debug "Unable to update version timestamp::: #{e.message}, Account:: #{id}"
      NewRelic::Agent.notice_error(e)
    end
  end

  # update domain name at Portal, Forum & Activities and support email

  def update_default_domain_and_email_config(new_domain_name, support_email_name)
    self.transaction do 
      update_account_and_main_portal_domain(new_domain_name)
      update_default_forum_category_name(new_domain_name)
      update_primary_email_config(support_email_name)
      self.make_current
      save!
    end
  end

  def signup_method
    @signup_method ||= (
      key = ACCOUNT_SIGN_UP_PARAMS % {:account_id => self.id}
      json_response = get_others_redis_key(key)
      json_response.present? ? JSON.parse(json_response)["signup_method"] : self.conversion_metric.try(:[], :session_json).try(:[], :signup_method)
    )
  end

  def email_signup?
    "email_signup" == self.signup_method.to_s
  end

  def active_suspended?
    @active_suspended ||= begin
      key = ACTIVE_SUSPENDED % {:account_id => self.id}
      get_others_redis_key(key) == true.to_s
    end
  end

  def allow_incoming_emails?
    self.active? || self.active_suspended?
  end

  def email_subscription_state
    #If the account is in suspended state the email service will not create the tickets for incoming mails. So, inorder to create the
    #tickets for state which  moved from paid(not trial) to suspended we are sending non_trial_suspended state. The email service will block only
    #if the account state is suspended.
    return self.subscription.state unless (self.subscription.suspended? && self.active_suspended?)
    'active_suspended'
  end

  protected
  
    def external_url_is_valid?(url) 
      uri = URI.parse(url) 
      response = Net::HTTP.start(uri.host, uri.port) {|http| http.head(uri.path)} 
      response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection) 
    rescue  ArgumentError
      false
    rescue Errno::ECONNREFUSED
      false
    rescue Errno::ETIMEDOUT
      false
    end 

    def generate_secret_token
      Digest::MD5.hexdigest(Helpdesk::SHARED_SECRET + self.full_domain + Time.now.to_f.to_s).downcase
    end
    
    def set_sso_options_hash
      HashWithIndifferentAccess.new({:login_url => "",:logout_url => "", :sso_type => ""})
    end
    
    # def create_admin
    #   self.user.active = true  
    #   self.user.account = self
    #   self.user.user_emails.first.account = self
    #   self.user.user_emails.first.verified = true
    #   self.user.user_role = User::USER_ROLES_KEYS_BY_TOKEN[:account_admin]  
    #   self.user.build_agent()
    #   self.user.agent.account = self
    #   self.user.save
    #   User.current = self.user
    # end

    def subscription_next_renewal_at
      subscription.next_renewal_at
    end

  private

    def update_account_and_main_portal_domain new_domain_name
      self.assign_attributes({
        :domain => new_domain_name,
        :name => new_domain_name.capitalize,
        :helpdesk_name => new_domain_name
      })
      self.main_portal.name = new_domain_name
    end
    
    def update_default_forum_category_name(new_domain_name)
      forum_category = forum_categories.first
      forum_category.name = "#{new_domain_name} Forums"
      forum_category.save!
      # account.activities.update_all(:created_at => Time.now.utc)
      # TODO ACTIVITIES - need to add set update activity service for updation of forum category.
      activities.where("notable_type LIKE 'Forum'").each do |activity|
        activity.activity_data["category_name"] = "#{new_domain_name} Forums"
        activity.save!
      end
    end

    def update_primary_email_config(support_email_name)
      primary_email_config.assign_attributes({
        :to_email => support_email_name + "@#{full_domain}",
        :reply_email => support_email_name + "@#{full_domain}",
        :name => name
      })
    end
end
