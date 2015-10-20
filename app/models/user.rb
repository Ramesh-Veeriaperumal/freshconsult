# encoding: utf-8
class User < ActiveRecord::Base  
  self.primary_key= :id

  belongs_to_account
  has_many :access_tokens, :class_name => 'Doorkeeper::AccessToken', :foreign_key => :resource_owner_id, :dependent => :destroy

  include SentientUser
  include Helpdesk::Ticketfields::TicketStatus
  include Mobile::Actions::User
  include Users::Activator
  include Users::Preferences
  include Authority::FreshdeskRails::ModelHelpers
  include Search::ElasticSearchIndex
  include Cache::Memcache::User
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Authority::FreshdeskRails::ModelHelpers
  include ApiWebhooks::Methods
  include Social::Ext::UserMethods
  include AccountConstants
  
  concerned_with :constants, :associations, :callbacks, :user_email_callbacks, :rabbitmq
  include CustomerDeprecationMethods, CustomerDeprecationMethods::NormalizeParams

  validates_uniqueness_of :twitter_id, :scope => :account_id, :allow_nil => true, :allow_blank => true
  validates_uniqueness_of :external_id, :scope => :account_id, :allow_nil => true, :allow_blank => true

  xss_sanitize  :only => [:name,:email,:language, :job_title], :plain_sanitizer => [:name,:email,:language, :job_title]
  scope :contacts, :conditions => { :helpdesk_agent => false }
  scope :technicians, :conditions => { :helpdesk_agent => true }
  scope :visible, :conditions => { :deleted => false }
  scope :active, lambda { |condition| { :conditions => { :active => condition }} }
  scope :with_conditions, lambda { |conditions| { :conditions => conditions} }
  # Using text_uc01 column as the preferences hash for storing user based settings
  serialize :text_uc01, Hash
  alias_attribute :preferences, :text_uc01  
  alias_method_chain :preferences, :defaults

  # Attributes used in Freshservice
  # alias_attribute :last_name, :string_uc02 # string_uc02 is used in Freshservice to store last name
  alias_attribute :user_type, :user_role # Used for "System User"
  alias_attribute :extn, :string_uc03 # Active Directory User - Phone Extension
    
  acts_as_authentic do |c|    
    c.login_field(:email)
    c.validate_login_field(false)
    c.validate_email_field(false)
    c.validations_scope = :account_id
    c.validates_length_of_password_field_options = {:on => :update, :minimum => PASSWORD_LENGTH, :if => :has_no_credentials? }
    c.validates_length_of_password_confirmation_field_options = {:on => :update, :minimum => PASSWORD_LENGTH, :if => :has_no_credentials?}    
    #The following is a part to validate email only if its not deleted
    c.merge_validates_format_of_email_field_options  :if =>:chk_email_validation?, :with => EMAIL_VALIDATOR
    c.merge_validates_length_of_email_field_options :if =>:chk_email_validation? 
    c.merge_validates_uniqueness_of_email_field_options :if =>:chk_email_validation?, :case_sensitive => true
    c.crypto_provider = Authlogic::CryptoProviders::Sha512
    c.validate :password_format?, :if => :require_password_check? #Password restriction hardcode
  end

  #Password restriction hardcode - TBD Remove after password_policy completed
  def require_password_check?
    !new_record? && password_changed? && Account.current.password_restriction_enabled?
  end

  def password_format?
    short =  self.password.blank? || self.password.length < 8
    alphanumeric = self.password =~ ALPHA_NUMERIC_REGEX #should have atleast one uppercase alphabet, one lowercase alphabet and one number
    special = self.password =~ SPECIAL_CHARACTERS_REGEX # special character
    username = self.password.downcase.include?(self.email[/.+(?=@)/].downcase) # should not contain username

    #No I18n, since only for Walby Parker and won't be used for password policy feature
    error_message = "Your password must have at least 8 characters,
                     an uppercase and lowercase alphabet, a number and a
                    special character, and must not be the same as your email id."
    self.errors.add(:base, error_message) if !alphanumeric or !special or username or short
  end
  #End Password restriction hardcode

  validate :has_role?, :unless => :customer?
  validate :email_validity, :if => :chk_email_validation?
  validate :user_email_presence, :if => :email_required?
  validate :only_primary_email, on: :update, :if => [:agent?, :has_contact_merge?]
  validate :max_user_emails, :if => [:has_contact_merge?]


  def email_validity
    self.errors.add(:base, I18n.t("activerecord.errors.messages.email_invalid")) unless self[:account_id].blank? or self[:email] =~ EMAIL_VALIDATOR
    self.errors.add(:base, I18n.t("activerecord.errors.messages.email_not_unique")) if self[:email] and self[:account_id].present? and User.exists?(["email = ? and id != '#{self.id}'", self[:email]])
  end

  def only_primary_email
    self.errors.add(:base, I18n.t('activerecord.errors.messages.agent_email')) unless (self.user_emails.length == 1)
  end

  def user_email_presence
    self.errors.add(:base, I18n.t("activerecord.errors.messages.user_emails")) if has_no_emails_with_ui_feature?
  end

  def max_user_emails
    self.errors.add(:base, I18n.t('activerecord.errors.messages.max_user_emails')) if (self.user_emails.reject(&:marked_for_destruction?).length > MAX_USER_EMAILS)
  end

  def has_no_emails_with_ui_feature?
    has_contact_merge? and (primary_email.blank? and self.user_emails.reject(&:marked_for_destruction?).empty?)
  end

  attr_accessor :import, :highlight_name, :highlight_job_title, :created_from_email, :primary_email_attributes
  
  attr_accessible :name, :email, :password, :password_confirmation, :primary_email_attributes, 
                  :user_emails_attributes, :second_email, :job_title, :phone, :mobile, :twitter_id, 
                  :description, :time_zone, :customer_id, :avatar_attributes, :company_id, 
                  :company_name, :tag_names, :import_id, :deleted, :fb_profile_id, :language, 
                  :address, :client_manager, :helpdesk_agent, :role_ids, :parent_id, :string_uc04

  def time_zone
    tz = self.read_attribute(:time_zone)
    tz = "Kyiv" if tz.eql?("Kyev")
    tz
  end

  def avatar_url(profile_size = :thumb)
    (avatar ? avatar.expiring_url(profile_size, 30.days.to_i) : is_user_social(profile_size)) if present?
  end

  def is_user_social(profile_size)
    if fb_profile_id
      profile_size = (profile_size == :medium) ? "large" : "square"
      facebook_avatar(fb_profile_id, profile_size)
    else
      "/assets/misc/profile_blank_#{profile_size}.gif"
    end
  end

  def facebook_avatar( facebook_id, profile_size = "square")
    "https://graph.facebook.com/#{facebook_id}/picture?type=#{profile_size}"
  end

  def ebay_user?
    (self.external_id && self.external_id =~ /\Afbay-/) ? true : false
  end
  
  class << self # Class Methods
    #Search display
    def search_display(user)
      "#{user.excerpts.name} - #{user.excerpts.email}"
    end
    #Search display ends here

    def filter(letter, page, state = "verified", per_page = 50,order_by = 'name')
      begin
        paginate(
                :per_page => per_page, 
                :page => page,
                :conditions => filter_condition(state, letter),
                :order => order_by
                ).preload(:flexifield)
      rescue Exception =>exp
        raise "Invalid fetch request for contacts"
      end
    end

    def filter_condition(state, letter)
      conditions = case state
        when "verified", "unverified"
           [ ' deleted = ? and active = ? and deleted_at IS NULL and blocked = false ', 
            false , state.eql?("verified") ]
        when "deleted", "all"
          [ ' deleted = ? and deleted_at IS NULL and blocked = false', 
            state.eql?("deleted")]
        when "blocked"
          [ ' ((blocked = ? and blocked_at <= ?) or (deleted = ? and  deleted_at <= ?)) and whitelisted = false ', 
            true, (Time.now+5.days).to_s(:db), true, (Time.now+5.days).to_s(:db) ]
      end
      
      conditions[0] = "#{conditions[0]} and name like '#{letter}%' " unless letter.blank?
      conditions
    end

    def find_by_email_or_name(value)
      conditions = {}
      if value =~ /(\b[-a-zA-Z0-9.'’_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b)/
        conditions[:email] = value
      else
        conditions[:name] = value
      end
      user = self.find(:first, :conditions => conditions)
      user
    end

    def find_by_an_unique_id(options = {})
      options.delete_if { |key, value| value.blank? }
      
      #return self.find(options[:id]) if options.key?(:id)
      return UserEmail.user_for_email(options[:email]) if options.key?(:email)
      return self.find_by_twitter_id(options[:twitter_id]) if options.key?(:twitter_id)
      return self.find_by_fb_profile_id(options[:fb_profile_id]) if options.key?(:fb_profile_id)
      return self.find_by_external_id(options[:external_id]) if options.key?(:external_id)
      return self.find_by_phone(options[:phone]) if options.key?(:phone)
    end 

    def update_posts_count
      self.class.update_posts_count id
    end
    
    def update_posts_count(id)
      User.update_all ['posts_count = ?', Post.count(:id, :conditions => {:user_id => id, :published => true})],   ['id = ?', id]
    end

    def reset_current_user
      User.current = nil
    end

    # Used by API V2
    def contact_filter(contact_filter)
      {
        deleted: {
          conditions: { deleted: true }
        },
        verified: {
          conditions: { deleted: false, active: true }
        },
        unverified: {
          conditions: { deleted: false, active: false }
        },
        blocked: {
          conditions: [ "blocked = true and blocked_at < ? and deleted = true and deleted_at < ?", Time.zone.now+5.days, Time.zone.now+5.days ]
        },
        all: {
          conditions: { deleted: false }
        },
        company_id: {
          conditions: { customer_id: contact_filter.company_id }
        },
        email: {
          joins: :user_emails, 
          conditions: { user_emails: { email: contact_filter.email }}
        },
        phone: {
          conditions: { phone: contact_filter.phone }
        },
        mobile: {
          conditions: { mobile: contact_filter.mobile }
        }
      }
    end

    # protected :find_by_email_or_name, :find_by_an_unique_id
  end

  def client_manager=(checked)
    if customer?
      self.privileges = ((checked == "true" || checked == true) && company ) ? Role.privileges_mask([:client_manager]) : "0"
    end
  end

  def client_manager
    has_company? ? privilege?(:client_manager) : false
  end

  def chk_email_validation?
    (is_not_deleted?) and (twitter_id.blank? || !email.blank?) and (fb_profile_id.blank? || !email.blank?) and
                          (external_id.blank? || !email.blank?) and (phone.blank? || !email.blank?) and
                          (mobile.blank? || !email.blank?)
  end

  def email_required?
    is_not_deleted? and twitter_id.blank? and fb_profile_id.blank? and external_id.blank? and phone.blank? and mobile.blank?
  end

  def add_tag(tag)
    # Tag the users if he is not already tagged
    self.tags.push tag unless tag.blank? or self.tagged?(tag.id)
  end

  def parent_id
    string_uc04.to_i
  end

  def parent_id?
    !parent_id.zero?
  end

  def parent_id=(p_id)
    self.string_uc04 = p_id.to_s
  end

  def tag_names= updated_tag_names
    unless updated_tag_names.nil? # Check only nil so that empty string will remove all the tags.
      updated_tag_names.strip! #strip! to avoid empty tag name error
      updated_tag_names = updated_tag_names.split(",")
      current_tags = account.tags_from_cache
      new_tags = []
      updated_tag_names.each do |updated_tag_name|
        updated_tag_name.strip!
        next if new_tags.any?{ |new_tag| new_tag.name.casecmp(updated_tag_name)==0 }

        new_tags.push(current_tags.find{ |current_tag| current_tag.name.casecmp(updated_tag_name) == 0 } ||
                      Helpdesk::Tag.new(:name => updated_tag_name ,:account_id => self.account.id))
      end
      self.tags = new_tags
    end
  end

  def tag_names
    tags.collect{|tag| tag.name}.join(', ')
  end

  def tagged?(tag_id)
    unless tag_id.blank?
      # To avoid DB query.
      self.tags.each {|tag|
        return true if tag.id == tag_id
      }
      # Check the tag_uses that are not yet committed in the DB, if any
      self.tag_uses.each {|tag_use|
        return true if tag_use.tag_id == tag_id
      }
    end
    return false
  end
	
	def available_number
		phone.blank? ? mobile : phone
	end

  def update_attributes(params) # Overriding to normalize params at one place
    normalize_params(params) # hack to facilitate contact_fields & deprecate customer
    if [:tag_names, :tags].any?{|attr| # checking old key for API & prevents resetting tags if its not intended 
     params.include?(attr)} && params[:tags].is_a?(String)
      tags = params.delete(:tags)
      params[:tag_names]||= tags
    end
    super(params)
  end

  def signup!(params , portal=nil, send_activation=true)
    normalize_params(params[:user]) # hack to facilitate contact_fields & deprecate customer
    params[:user][:tag_names] = params[:user][:tags] unless params[:user].include?(:tag_names)
    self.name = params[:user][:name]
    self.phone = params[:user][:phone]
    self.mobile = params[:user][:mobile]
    self.twitter_id = params[:user][:twitter_id]
    self.external_id = params[:user][:external_id]
    self.description = params[:user][:description]
    self.company_name = params[:user][:company_name] if params[:user].include?(:company_name)
    self.company_id = params[:user][:company_id] if params[:user].include?(:company_id)
    self.job_title = params[:user][:job_title]
    self.helpdesk_agent = params[:user][:helpdesk_agent] || false
    self.client_manager = params[:user][:client_manager]
    self.role_ids = params[:user][:role_ids] || []
    self.time_zone = params[:user][:time_zone]
    self.import_id = params[:user][:import_id]
    self.fb_profile_id = params[:user][:fb_profile_id]
    self.email = params[:user][:email]
    self.language = params[:user][:language]
    self.address = params[:user][:address]
    self.tag_names = params[:user][:tag_names] # update tags in the user object
    self.custom_field = params[:user][:custom_field]
    self.avatar_attributes=params[:user][:avatar_attributes] unless params[:user][:avatar_attributes].nil?
    self.user_emails_attributes = params[:user][:user_emails_attributes] if params[:user][:user_emails_attributes].present? and has_contact_merge?
    self.deleted = true if (email.present? && email =~ /MAILER-DAEMON@(.+)/i)
    self.created_from_email = params[:user][:created_from_email] 
    return false unless save_without_session_maintenance
    portal.make_current if portal
    if (!deleted and !email.blank? and send_activation)
      args = [ portal,false, params[:email_config]]
      job_args = self.language ? [nil] : [nil, 5.minutes.from_now]
      Delayed::Job.enqueue(Delayed::PerformableMethod.new(self, :deliver_activation_instructions!, args), *job_args) 
    end
    true
  end

  # Used by API V2
  def create_contact!
    self.avatar = self.avatar
    return false unless save_without_session_maintenance
    if (!self.deleted and !self.email.blank?)
      portal = nil
      force_notification = false
      args = [ portal, force_notification ]
      Delayed::Job.enqueue(Delayed::PerformableMethod.new(self, :deliver_activation_instructions!, args), nil, 2.minutes.from_now)
    end
    true
  end

  #This scope is currently used only for failure searches through ES for contact_merge search

  scope :matching_users_from, lambda { |search|
    {
      :select => %(users.id, name, users.account_id, users.string_uc04, users.email, GROUP_CONCAT(user_emails.email) as `additional_email`, 
        twitter_id, fb_profile_id, phone, mobile, job_title, customer_id),
      :joins => %(left join user_emails on user_emails.user_id=users.id and 
        user_emails.account_id = users.account_id) % { :str => "%#{search}%" },
      :conditions => %((name like '%<str>s' or user_emails.email 
        like '%<str>s' and deleted = 0)) % {
        :str => "%#{search}%"      
      },
      
      :group => "users.id",
    }
  }

  scope :without, lambda { |source|
    {
      :conditions => "users.id <> %<us_id>i" % {
        :us_id => source.id
      }
    }
  }

  def signup(portal=nil)
    return false unless save_without_session_maintenance
    deliver_activation_instructions!(portal,false) if (!deleted and self.email.present?)
    true
  end
 
  def active?
    active
  end
  
  def has_email?
    !self.email.blank?
  end

  
  def activate!(params)
    self.active = true
    self.name = params[:user][:name]
    self.password = params[:user][:password]
    self.password_confirmation = params[:user][:password_confirmation]
    # self.user_emails.first.update_attributes({:verified => true}) unless self.user_emails.blank?
    #self.openid_identifier = params[:user][:openid_identifier]
    save
  end

  def exist_in_db?
    !(id.blank?)
  end

  def has_no_credentials?
    self.crypted_password.blank? && active? && !account.sso_enabled? && !deleted && self.authorizations.empty? && self.twitter_id.blank? && self.fb_profile_id.blank? && self.external_id.blank?
  end

  def first_name
    name_part("given").split.first
  end

  def last_name
    name_part("family")
  end

  #Savage_beast changes start here
  #implement in your user model 
  def display_name
    to_s
  end

  #implement in your user model 

  def agent?
    helpdesk_agent
  end
  alias :is_agent :agent?

  def customer?
    !agent?
  end
  alias :is_customer :customer?
  
  # Used in mobile
  def is_client_manager?
    self.privilege?(:client_manager)
  end

  # Marketplace
  def developer?
    marketplace_developer_application = Doorkeeper::Application.find_by_name(Marketplace::Constants::DEV_PORTAL_NAME)
    developer_privilege = access_tokens.find_by_application_id(marketplace_developer_application.id) if self.access_tokens
    Account.current.features?(:fa_developer) && !developer_privilege.blank?
  end

  def can_assume?(user)
    # => Not himself
    # => User is not deleted
    # => And the user does not have any admin privileges (He is an agent)
    !((user == self) or user.deleted? or user.privilege?(:view_admin))
  end

  def api_assumable?
    !deleted? && privilege?(:manage_tickets)
  end
  
  def first_login?
    login_count <= 2
  end
  
  #Savage_beast changes end here

  ##Authorization copy starts here
  def name_details #changed name_email to name_details
    return "#{format_name} <#{email}>" unless email.blank?
    return "#{name} (#{phone})" unless phone.blank?
    return "#{name} (#{mobile})" unless mobile.blank?
    return "@#{twitter_id}" unless twitter_id.blank?
    name
  end

  def search_data
    if has_contact_merge? and self.user_emails.present?
      self.user_emails.map{|x| {:id => id, :details => "#{format_name} <#{x.email}>", :value => name, :email => x.email}}
    else
      [{:id => id, :details => self.name_details, :value => name, :email => email}]
    end
  end

  ##Authorization copy ends here
  
  def url_protocol
    if account.main_portal_from_cache.portal_url.blank? 
      return account.ssl_enabled? ? 'https' : 'http'
    else 
      return account.main_portal_from_cache.ssl_enabled? ? 'https' : 'http'
    end
  end
  
  def to_s
    name.blank? ? email : name
  end
  
  def to_liquid
    @user_drop ||= UserDrop.new self
  end

  def emails
    user_emails.map(&:email)
  end

  def is_not_deleted?
    Rails.logger.debug "not ::deleted ?:: #{!self.deleted}"
    !self.deleted
  end
  
  def occasional_agent?
    agent && agent.occasional
  end

  def day_pass_granted_on(start_time = DayPassUsage.start_time) #Revisit..
    day_pass_usages.on_the_day(start_time).first
  end
  
  def spam?
    deleted && !deleted_at.nil?
  end

  def get_info
    (email) || (twitter_id) || (external_id) || (name)
  end
  
  def twitter_style_id
    "@#{twitter_id}"
  end
  
  def can_view_all_tickets?
    self.privilege?(:manage_tickets) && agent.all_ticket_permission
  end
  
  def group_ticket_permission
    self.privilege?(:manage_tickets) && agent.group_ticket_permission
  end

  def assigned_ticket_permission
    self.privilege?(:manage_tickets) && agent.assigned_ticket_permission
  end
  
  def has_ticket_permission? ticket
    (can_view_all_tickets?) or (ticket.responder_id == self.id ) or (ticket.requester_id == self.id) or (group_ticket_permission && (ticket.group_id && (agent_groups.collect{|ag| ag.group_id}.insert(0,0)).include?( ticket.group_id))) 
  end

  # For a customer we need to check if he is the requester of the ticket
  # Or if he is allowed to view tickets from his company
  def has_customer_ticket_permission?(ticket)
    (self.id == ticket.requester_id) or 
    (is_client_manager? && self.company_id && ticket.requester.company_id && (ticket.requester.company_id == self.company_id) )
  end
  
  def restricted?
    !can_view_all_tickets?
  end

  def to_xml(options=USER_API_OPTIONS)
    process_api_options USER_API_OPTIONS, options
    super options do |builder|
      unless helpdesk_agent
        builder.custom_field do
          custom_field.each do |name, value|
            builder.tag!(name,value) unless value.nil?
          end
        end
      end
    end
  end

  def as_json(options = nil, do_not_process_options = false)
    default_options = helpdesk_agent? ? USER_API_OPTIONS : CONTACT_API_OPTIONS
    options ||= default_options
    process_api_options default_options, options unless do_not_process_options
    super(options)
  end

  def to_indexed_json
    as_json({
              :root => "user",
              :tailored_json => true,
              :only => [ :name, :email, :description, :job_title, :phone, :mobile,
                         :twitter_id, :fb_profile_id, :account_id, :deleted,
                         :helpdesk_agent, :created_at, :updated_at ], 
              :include => { :customer => { :only => [:name] },
                            :user_emails => { :only => [:email] }, 
                            :flexifield => { :only => es_contact_field_data_columns } } }, true
           ).to_json
  end

  def es_contact_field_data_columns
    @@es_contact_field_data_columns ||= ContactFieldData.column_names.select{ |column_name| 
                                    column_name =~ /^cf_(str|text|int|decimal|date)/}.map &:to_sym
  end
  
  def es_columns
    @@es_columns ||= [:name, :email, :description, :job_title, :phone, :mobile, :twitter_id, 
      :fb_profile_id, :customer_id, :deleted, :helpdesk_agent].concat(es_contact_field_data_columns)
  end

  def has_company?
    customer? and company
  end

  def company_name= name
    self.company = name.blank? ? nil : account.companies.find_or_create_by_name(name)
  end
  
  def company_name
    company.name unless company.nil?
  end

  def recent_tickets(limit = 5)
    tickets.newest(limit)
  end

  def available_quests
    account.quests.available(self)
  end

  def achieved_quest(quest)
    achieved_quests.find_by_quest_id(quest.id)
  end

  def badge_awarded_at(quest)
    achieved_quest(quest).updated_at
  end

  def reset_primary_email primary
    new_primary = self.user_emails.find(primary.to_i)
    if new_primary
      self.user_emails.update_all(:primary_role => false)
      new_primary.toggle!(:primary_role) #can refactor
    end
    return true
  end
  
  def make_customer
    return true if customer?
    if update_attributes({:helpdesk_agent => false, :deleted => false})
      subscriptions.destroy_all
      agent.destroy
      freshfone_user.destroy if freshfone_user
      email_notification_agents.destroy_all
      return true
    end 
    return false
  end
  
  def make_agent(args = {})
    ActiveRecord::Base.transaction do
      self.user_emails = [self.primary_email] if has_multiple_user_emails?
      self.deleted = false
      self.helpdesk_agent = true
      self.company = nil
      self.address = nil
      self.role_ids = [account.roles.find_by_name("Agent").id] 
      agent = build_agent()
      agent.occasional = !!args[:occasional]
      save ? true : (raise ActiveRecord::Rollback)
    end
  end

  def update_search_index
    SearchSidekiq::IndexUpdate::UserTickets.perform_async({ :user_id => id }) if ES_ENABLED
  end

  def moderator_of?(forum)
    moderatorships.count(:all, :conditions => ['forum_id = ?', (forum.is_a?(Forum) ? forum.id : forum)]) == 1
  end

  def make_current
    User.current = self
  end

  def self.reset_current_user
    User.current = nil
  end
  
  def user_time_zone
    self.time_zone
  end
  
  def user_tag
    self.tags
  end

  def language_name
    Language.find_by_code(self.language.to_s).try(:name)
  end

  def custom_form
    helpdesk_agent? ? nil : (Account.current || account).contact_form # memcache this 
  end

  def custom_field_aliases
    @custom_field_aliases ||= (helpdesk_agent? || account.blank?) ? [] : custom_form.custom_contact_fields.map(&:name)
  end

  def custom_field_types
    @custom_field_types ||= (helpdesk_agent? || account.blank?) ? {} : custom_form.custom_contact_fields.inject({}) { |types,field| types.merge(field.name => field.field_type) }
  end

  def self.search_by_name search_by, account_id, options = { :load => true, :page => 1, :size => 10, :preference => :_primary_first }
    return [] if search_by.blank? || (search_by = search_by.gsub(/[\^\$]/, '')).blank?
    begin
      Search::EsIndexDefinition.es_cluster(account_id)
      item = Tire.search Search::EsIndexDefinition.searchable_aliases([User], account_id), options do |search|
        search.query do |query|
          query.filtered do |f|
            if SearchUtil.es_exact_match?(search_by)
              f.query { |q| q.match ["name", "email", "user_emails.email"], SearchUtil.es_filter_exact(search_by), :type => :phrase } 
            else
              f.query { |q| q.string SearchUtil.es_filter_key(search_by), :fields => ['name', 'email', 'user_emails.email'], :analyzer => "include_stop" }
            end
            f.filter :term, { :account_id => account_id }
            f.filter :term, { :deleted => false }
          end
        end
        search.from options[:size].to_i * (options[:page].to_i-1)
        search.highlight :description, :name, :job_title, :options => { :tag => '<strong>', :fragment_size => 50, :number_of_fragments => 4, :encoder => 'html' }
      end
      item.results
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      []
    end 
  end


  # Hack to sanitize phone, mobile from api when passed as integer
  def phone=(value)
    value = value.nil? ? value : value.to_s
    write_attribute(:phone, RailsFullSanitizer.sanitize(value))
  end

  def mobile=(value)
    value = value.nil? ? value : value.to_s 
    write_attribute(:mobile, RailsFullSanitizer.sanitize(value))
  end
  # Hack ends here
  
  def search_fields_updated?
    (@all_changes.keys & es_columns).any?
  end

  def company_id
    self.customer_id
  end

  # failed_login_count increases for each consecutive failed login.
  # See Authlogic::Session::BruteForceProtection and the consecutive_failed_logins_limit config option for more details.
  def update_failed_login_count(valid_pwd, user_name = nil, ip = nil)
    if valid_pwd
      # reset failed_login_count only when it has changed. This is to prevent unnecessary save on user.
      if self.failed_login_count != 0
        self.failed_login_count = 0 
        self.save
      end
      self
    else
      self.failed_login_count ||= 0
      self.failed_login_count += 1
      self.save
      Rails.logger.error "API Unauthorized Error: Failed login attempt '#{self.failed_login_count}' for '#{user_name}' from #{ip} at #{Time.now.utc}"
      nil
    end
  end

  private
    def name_part(part)
      part = parsed_name[part].blank? ? "particle" : part unless parsed_name.blank? and part == "family"
      parsed_name[part].blank? ? name : parsed_name[part]
    end

    def parsed_name
      @parsed_name ||= Namae::Name.parse(self.name)
    end

    def backup_user_changes
      @all_changes = self.changes.clone.to_hash
      @all_changes.merge!(flexifield.changes)
      @all_changes.symbolize_keys!
    end

    def helpdesk_agent_updated?
      @all_changes.has_key?(:helpdesk_agent)
    end

    def email_updated?
       @all_changes.has_key?(:email)
    end
    
    def company_id_updated?
      @all_changes.has_key?(:customer_id)
    end

    def privileges_updated?
      @all_changes.has_key?(:privileges)
    end

    def company_info_updated?
      company_id_updated? or privileges_updated?
    end

    def clear_redis_for_agent
      if helpdesk_agent_changed? and !agent?
        self.agent_groups.each do |ag|
          group = ag.group
          group.remove_agent_from_round_robin(self.id) if group.round_robin_enabled?
        end
      end
    end

    def touch_role_change(role)
      @role_change_flag = true
    end

    def roles_changed?
      !!@role_change_flag
    end

    def has_role?
      self.errors.add(:base, I18n.t("activerecord.errors.messages.user_role")) if
        ((@role_change_flag or new_record?) && self.roles.blank?)
    end

    #This is the current login method. It is fed to authlogic in user_sessions.rb

    def self.find_by_user_emails(login)
      if !Account.current.features_included?(:multiple_user_emails)
        user = User.find_by_email(login)
        user if user.present? and user.active? and !user.blocked?
      else
        # Without using select will results in making the user object readonly.
        # http://stackoverflow.com/questions/639171/what-is-causing-this-activerecordreadonlyrecord-error
        user = User.select("`users`.*").joins("INNER JOIN `user_emails` ON `user_emails`.`user_id` = `users`.`id` AND `user_emails`.`account_id` = `users`.`account_id`").where(user_emails: {email: login}).first
        user if !user.nil? and user.active? and !user.blocked?
      end
    end

    def process_api_options default_options, current_options
      default_options.each do |key, value| 
        current_options[key] = current_options.key?(key) ? current_options[key] & default_options[key] : default_options[key]
      end
    end

    def format_name
      (name =~ SPECIAL_CHARACTERS_REGEX and name !~ /".+"/) ? "\"#{name}\"" : name
    end

end
