class Account < ActiveRecord::Base
  require 'net/dns/resolver'

  #rebranding starts
  serialize :preferences, Hash
  has_one :logo,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :conditions => ['description = ?', 'logo' ],
    :dependent => :destroy
  
  has_one :fav_icon,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :conditions => ['description = ?', 'fav_icon' ],
    :dependent => :destroy
    
  #rebranding ends 

  RESERVED_DOMAINS = %W(  blog help chat smtp mail www ftp imap pop faq docs doc wiki team people india us talk 
                          upload download info lounge community forums ticket tickets tour about pricing bugs in out 
                          logs projects itil marketing sales partners partner store channel reseller resellers online 
                           login contact admin #{AppConfig['admin_subdomain']} girish shan vijay parsu kiran shihab )

  #
  # Tell authlogic that we'll be scoping users by account
  #
  authenticates_many :user_sessions
  
  has_many :users, :dependent => :destroy , :conditions =>{:deleted =>false}
  has_many :all_users , :class_name => 'User', :dependent => :destroy
  has_one :admin, :class_name => "User", :conditions => { :user_role => User::USER_ROLES_KEYS_BY_TOKEN[:admin] } #has_one ?!?!?!?!
  has_one :subscription, :dependent => :destroy
  has_many :subscription_payments
  has_many :solution_categories , :class_name =>'Solution::Category',:include =>:folders
  has_many :solution_articles , :class_name =>'Solution::Article'
  
  has_many :customers, :dependent => :destroy
  has_many :contacts, :class_name => 'User' , :conditions =>{:user_role => User::USER_ROLES_KEYS_BY_TOKEN[:customer] , :deleted =>false}
  has_many :agents, :through =>:users , :conditions =>{:users=>{:deleted => false}}
  has_many :all_contacts , :class_name => 'User', :conditions =>{:user_role => User::USER_ROLES_KEYS_BY_TOKEN[:customer]}
  has_many :all_agents, :class_name => 'Agent', :through =>:all_users  , :source =>:agent
  has_many :sla_policies , :class_name => 'Helpdesk::SlaPolicy' ,:dependent => :destroy
  
  #Scoping restriction for other models starts here
  has_many :va_rules, :class_name => 'VARule', :conditions => {:rule_type => VAConfig::BUSINESS_RULE, :active => true}, :order => "position"
  has_many :disabled_va_rules, :class_name => 'VARule', :conditions => {:rule_type => VAConfig::BUSINESS_RULE, :active => false}, :order => "position"
  has_many :all_va_rules, :class_name => 'VARule', :conditions => {:rule_type => VAConfig::BUSINESS_RULE}, :order => "position"
  
  has_many :scn_automations, :class_name => 'VARule', :conditions => {:rule_type => VAConfig::SCENARIO_AUTOMATION, :active => true}, :order => "position"
  has_many :email_configs
  has_one  :primary_email_config, :class_name => 'EmailConfig', :conditions => { :primary_role => true }
  has_many :email_notifications
  has_many :groups
  has_many :forum_categories
  
  has_one :business_calendar
  
  has_many :tickets, :class_name => 'Helpdesk::Ticket'
  has_many :solution_folders , :class_name =>'Solution::Folder'
  
  has_one :form_customizer , :class_name =>'Helpdesk::FormCustomizer'
  
  #Scope restriction ends
  
  validates_format_of :domain, :with => /\A[a-zA-Z][a-zA-Z0-9]*\Z/
  validates_exclusion_of :domain, :in => RESERVED_DOMAINS, :message => "The domain <strong>{{value}}</strong> is not available."
  validate :valid_domain?
  validate :valid_helpdesk_url?
  validate_on_create :valid_user?
  validate_on_create :valid_plan?
  validate_on_create :valid_payment_info?
  validate_on_create :valid_subscription?
  
  attr_accessible :name, :domain, :user, :plan, :plan_start, :creditcard, :address,:preferences,:logo_attributes,:fav_icon_attributes,:ticket_display_id
  attr_accessor :user, :plan, :plan_start, :creditcard, :address, :affiliate
  
  validates_numericality_of :ticket_display_id,
                            :less_than => 1000000,
                            :message => "Value must be less than six digits"
                            

  before_create :set_default_values, :config_default_email
  
  before_update :check_default_values
    
  after_create :create_admin
  after_create :populate_seed_data
  after_create :send_welcome_email
  
  acts_as_paranoid
  
  Limits = {
    'user_limit' => Proc.new {|a| a.users.count }
  }
  
  Limits.each do |name, meth|
    define_method("reached_#{name}?") do
      return false unless self.subscription
      self.subscription.send(name) && self.subscription.send(name) <= meth.call(self)
    end
  end
  
  def get_max_display_id
    ticket_dis_id = self.ticket_display_id
    max_dis_id = self.tickets.maximum('display_id')
    return  ticket_dis_id > max_dis_id ? ticket_dis_id : max_dis_id
  end
  
  def check_default_values
    dis_max_id = get_max_display_id
    if self.ticket_display_id.blank? or (self.ticket_display_id < dis_max_id)
       self.ticket_display_id = dis_max_id
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
    self.subscription.next_renewal_at >= Time.now
  end
  
  def domain
    @domain ||= self.full_domain.blank? ? '' : self.full_domain.split('.').first
  end
  
  def domain=(domain)
    @domain = domain
    self.full_domain = "#{domain}.#{AppConfig['base_domain']}"
  end
  
  def default_email
    primary_email_config.reply_email
  end
  
  def to_s
    name.blank? ? full_domain : "#{name} (#{full_domain})"
  end
  
  #Will be used as :host in emails
  def host
    helpdesk_url.blank? ? full_domain : helpdesk_url
  end
  
  #Helpdesk hack starts here
  def reply_emails
    (email_configs.collect { |ec| ec.reply_email }).sort
  end
  #HD hack ends..
  
  #Sentient things start here, can move to lib some time later - Shan
  def self.current
    Thread.current[:account]
  end
  
  def make_current
    Thread.current[:account] = self
  end
  #Sentient ends here
  
  protected
  
    def valid_domain?
      conditions = new_record? ? ['full_domain = ?', self.full_domain] : ['full_domain = ? and id <> ?', self.full_domain, self.id]
      self.errors.add(:domain, 'is not available') if self.full_domain.blank? || self.class.count(:conditions => conditions) > 0
    end
    
    def valid_helpdesk_url?
      return true if (helpdesk_url.blank? || helpdesk_url == full_domain)

      errors.add_to_base(<<-eos
                          Host verification failed, please configure a CNAME record in your DNS server 
                          for '#{helpdesk_url}' and alias it to '#{full_domain}'
                        eos
                        ) unless (cname == full_domain)
    end
    
    def cname
      begin
        Net::DNS::Resolver.new.query(helpdesk_url).each_cname do |cn| 
          return cn.sub(/\.?$/, '') if cn.include?(full_domain)
        end
      rescue Exception => e
        logger.debug "Host name verification failed #{e.message}"
      end
    end
    
    # An account must have an associated user to be the administrator
    def valid_user?
      if !@user
        errors.add_to_base("Missing user information")
      elsif !@user.valid?
        @user.errors.full_messages.each do |err|
          errors.add_to_base(err)
        end
      end
    end
    
    def valid_payment_info?
      if needs_payment_info?
        unless @creditcard && @creditcard.valid?
          errors.add_to_base("Invalid payment information")
        end
        
        unless @address && @address.valid?
          errors.add_to_base("Invalid address")
        end
      end
    end
    
    def valid_plan?
      errors.add_to_base("Invalid plan selected.") unless @plan
    end
    
    def valid_subscription?
      return if errors.any? # Don't bother with a subscription if there are errors already
      self.build_subscription(:plan => @plan, :next_renewal_at => @plan_start, :creditcard => @creditcard, :address => @address, :affiliate => @affiliate)
      if !subscription.valid?
        errors.add_to_base("Error with payment: #{subscription.errors.full_messages.to_sentence}")
        return false
      end
    end
    
    def set_default_values
      self.time_zone = Time.zone.name if time_zone.nil? #by Shan temp.. to_s is kinda hack.
      self.helpdesk_name = name.titleize if helpdesk_name.nil?
      self.preferences = HashWithIndifferentAccess.new({:bg_color => "#efefef",:header_color => "#2f3733", :tab_color => "#7cb537"})
    end
    
    def config_default_email
      d_email = "support@#{full_domain}"
      email_configs.build(:to_email => d_email, :reply_email => d_email, :primary_role => true)
    end
    
    def create_admin
      self.user.active = true
      self.user.account = self
      self.user.user_role = User::USER_ROLES_KEYS_BY_TOKEN[:admin]  
      self.user.build_agent()
      self.user.save
      
    end

    def populate_seed_data
      PopulateAccountSeed.populate_for(self)
    end

    def send_welcome_email
      SubscriptionNotifier.send_later(:deliver_welcome, self)
    end
    
end
