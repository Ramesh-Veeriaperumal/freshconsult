class Account < ActiveRecord::Base

  self.primary_key = :id
  
  include Mobile::Actions::Account
  include Social::Ext::AccountMethods
  include Cache::Memcache::Account
  include Redis::RedisKeys
  include Redis::TicketsRedis
  include Redis::DisplayIdRedis
  include ErrorHandle
  include AccountConstants

  has_many_attachments
  
  serialize :sso_options, Hash
  
  concerned_with :associations, :constants, :validations, :callbacks
  include CustomerDeprecationMethods
  # Please keep this one after the ar after_commit callbacks - rails 3
  include ObserverAfterCommitCallbacks
  
  xss_sanitize  :only => [:name,:helpdesk_name]
  
  attr_accessible :name, :domain, :user, :plan, :plan_start, :creditcard, :address,
                  :logo_attributes,:fav_icon_attributes,:ticket_display_id,:google_domain ,
                  :language, :ssl_enabled, :whitelisted_ip_attributes, :account_additional_settings_attributes,
                  :primary_email_config_attributes, :main_portal_attributes

  attr_accessor :user, :plan, :plan_start, :creditcard, :address, :affiliate
  
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
      self.subscription.send(name) && self.subscription.send(name) <= meth.call(self)
    end
  end

  has_features do
    PLANS_AND_FEATURES.each_pair do |k, v|
      feature k, :requires => ( v[:inherits] || [] )
      v[:features].each { |f_n| feature f_n, :requires => [] } unless v[:features].nil?
      SELECTABLE_FEATURES.keys.each { |f_n| feature f_n }
    end
  end
  
  def freshfone_enabled?
    features?(:freshfone) and freshfone_account.present?
  end

  def freshchat_enabled?
    features?(:chat)
  end

  def freshfone_active?
    features?(:freshfone) and freshfone_numbers.present?
  end

  def active_groups
    active_groups_in_account(id)
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
    installed_apps = installed_applications.all(:include => :application )
    installed_apps.inject({}) do |result,installed_app|
     result[installed_app.application.name.to_sym] = installed_app
     result
   end
  end
  
  def can_add_agents?(agent_count)
    subscription.agent_limit.nil? or 
      (subscription.agent_limit >= (agent_count + full_time_agents.count))
  end
  
  def get_max_display_id
    ticket_dis_id = self.ticket_display_id
    max_dis_id = self.tickets.maximum('display_id')
    unless max_dis_id.nil?
      return  ticket_dis_id > max_dis_id ? ticket_dis_id : max_dis_id+1
    end
    return 0
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
    !self.subscription.suspended?
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
    primary_email_config.friendly_email
  end

  def default_friendly_email_personalize(user_name)
    primary_email_config.friendly_email_personalize(user_name)
  end
  
  def default_email
    primary_email_config.reply_email
  end
  
  def to_s
    name.blank? ? full_domain : "#{name} (#{full_domain})"
  end
  
  #Will be used as :host in emails
  def host
    main_portal.portal_url.blank? ? full_domain : main_portal.portal_url
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

      features.send(s_plan).create
      p_features[:features].each { |f_n| features.send(f_n).create } unless p_features[:features].nil?
    end
  end
  
  def remove_features_of(s_plan)
    p_features = PLANS_AND_FEATURES[s_plan]
    unless p_features.nil?
      p_features[:inherits].each { |p_n| remove_features_of(p_n) } unless p_features[:inherits].nil?
      
      features.send(s_plan).destroy
      p_features[:features].each { |f_n| features.send(f_n).destroy } unless p_features[:features].nil?
    end
  end

  def add_features(feature_list)
    features.build(*feature_list)
  end

  def remove_feature(feature)
    features.send(feature).destroy
  end
  
  def ticket_type_values
    ticket_fields.type_field.first.picklist_values
  end
  
  def ticket_status_values
    ticket_statuses.visible
  end
  
  def has_multiple_products?
    !products.empty?
  end
  
  def kbase_email
    "kbase@#{full_domain}"
  end
  
  def has_credit_card?
    !subscription.card_number.nil?
  end

  def pass_through_enabled?
    pass_through_enabled
  end

  def user_emails_migrated?
    $redis_others.sismember('user_email_migrated', self.id)
  end

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

  def rabbit_mq_exchange
    $rabbitmq_shards[id%($rabbitmq_shards).count]
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

end
