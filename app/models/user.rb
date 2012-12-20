class User < ActiveRecord::Base
  
  belongs_to_account
  include ActionController::UrlWriter
  include SavageBeast::UserInit
  include SentientUser
  include Helpdesk::Ticketfields::TicketStatus
  include Mobile::Actions::User
  include Users::Activator
  include Cache::Memcache::User

  USER_ROLES = [
    [ :admin,       "Admin",            1 ],
    [ :poweruser,   "Power User",       2 ],
    [ :customer,    "Customer",         3 ],
    [ :account_admin,"Account admin",   4 ],
    [ :client_manager,"Client Manager", 5 ],
    [ :supervisor,    "Supervisor"    , 6 ]
   ]

  USER_ROLES_OPTIONS = USER_ROLES.map { |i| [i[1], i[2]] }
  USER_ROLES_NAMES_BY_KEY = Hash[*USER_ROLES.map { |i| [i[2], i[1]] }.flatten]
  USER_ROLES_KEYS_BY_TOKEN = Hash[*USER_ROLES.map { |i| [i[0], i[2]] }.flatten]
  USER_ROLES_SYMBOL_BY_KEY = Hash[*USER_ROLES.map { |i| [i[2], i[0]] }.flatten]
  EMAIL_REGEX = /(\A[-A-Z0-9.'’_%=+]+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,4}|museum|travel)\z)/i

  belongs_to :customer
  
  has_many :authorizations, :dependent => :destroy
  has_many :votes, :dependent => :destroy
  has_many :day_pass_usages, :dependent => :destroy
  
  has_many :time_sheets , :class_name =>'Helpdesk::TimeSheet' , :dependent => :destroy
   
  has_many :email_notification_agents,  :dependent => :destroy
  
  validates_uniqueness_of :user_role, :scope => :account_id, :if => Proc.new { |user| user.user_role  == USER_ROLES_KEYS_BY_TOKEN[:account_admin] }
  validates_uniqueness_of :twitter_id, :scope => :account_id, :allow_nil => true, :allow_blank => true
  validates_uniqueness_of :external_id, :scope => :account_id, :allow_nil => true, :allow_blank => true
  
  has_many :tag_uses,
    :as => :taggable,
    :class_name => 'Helpdesk::TagUse',
    :dependent => :destroy

  has_many :tags, 
    :class_name => 'Helpdesk::Tag',
    :through => :tag_uses

  has_many :google_contacts, :dependent => :destroy

  has_one :avatar,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy

  has_many :support_scores, :dependent => :delete_all

  before_create :set_time_zone , :set_company_name , :set_language
  before_save :set_account_id_in_children , :set_contact_name, :check_email_value , :set_default_role
  after_update :drop_authorization , :if => :email_changed?
  after_update :update_admin_in_crm , :if => :account_admin_updated?
  after_update :update_admin_to_billing , :if => :account_admin_updated?

  after_commit_on_create :clear_agent_list_cache, :if => :agent?
  after_commit_on_update :clear_agent_list_cache, :if => :agent?
  after_commit_on_destroy :clear_agent_list_cache, :if => :agent?
  after_commit_on_update :clear_agent_list_cache, :if => :user_role_updated?
  before_update :bakcup_user_changes
  
  named_scope :account_admin, :conditions => ["user_role = #{USER_ROLES_KEYS_BY_TOKEN[:account_admin]}" ]
  named_scope :contacts, :conditions => ["user_role in (#{USER_ROLES_KEYS_BY_TOKEN[:customer]}, #{USER_ROLES_KEYS_BY_TOKEN[:client_manager]})" ]
  named_scope :technicians, :conditions => ["user_role not in (#{USER_ROLES_KEYS_BY_TOKEN[:customer]}, #{USER_ROLES_KEYS_BY_TOKEN[:client_manager]})"]
  named_scope :visible, :conditions => { :deleted => false }
  named_scope :allowed_to_assume, lambda { |user|
    if user.supervisor?
      { :conditions => ["user_role not in (#{USER_ROLES_KEYS_BY_TOKEN[:admin]}, #{USER_ROLES_KEYS_BY_TOKEN[:account_admin]}) and id != ?", user.id]} 
    elsif user.admin?  
      { :conditions => ["user_role not in (#{USER_ROLES_KEYS_BY_TOKEN[:account_admin]}) and id != ?", user.id]} 
    else   
      { :conditions => ["id != ?", user.id]}  
    end      
  }
  named_scope :with_conditions, lambda { |conditions| { :conditions => conditions} }

  acts_as_authentic do |c|    
    c.validations_scope = :account_id
    c.validates_length_of_password_field_options = {:on => :update, :minimum => 4, :if => :has_no_credentials? }
    c.validates_length_of_password_confirmation_field_options = {:on => :update, :minimum => 4, :if => :has_no_credentials?}    
    #The following is a part to validate email only if its not deleted
    c.merge_validates_format_of_email_field_options  :if =>:chk_email_validation?, :with => EMAIL_REGEX
    c.merge_validates_length_of_email_field_options :if =>:chk_email_validation? 
    c.merge_validates_uniqueness_of_email_field_options :if =>:chk_email_validation? 
  end
  
  validates_presence_of :email, :unless => :customer?
  
  def check_email_value
    if email.blank?
      self.email = nil
    end
  end
  
  def chk_email_validation?
    (is_not_deleted?) and (twitter_id.blank? || !email.blank?) and (fb_profile_id.blank? || !email.blank?) and
                          (external_id.blank? || !email.blank?) and (phone.blank? || !email.blank?) and
                          (mobile.blank? || !email.blank?)
  end

  def add_tag(tag)
    # Tag the users if he is not already tagged
    self.tags.push tag unless tag.blank? or self.tagged?(tag.id)
  end

  def update_tag_names(csv_tag_names)
    unless csv_tag_names.nil? # Check only nil so that empty string will remove all the tags.
      updated_tag_names = csv_tag_names.split(",")
      new_tags = []
      updated_tag_names.each { |updated_tag_name|
        updated_tag_name = updated_tag_name.strip
        m=false
        new_tags.each { |fetched_tag|
          m=true if fetched_tag.name == updated_tag_name
        }
        next if m
        # TODO Below line executes query for every iteration.  Better to use some cached objects.
        new_tags.push self.account.tags.find_by_name(updated_tag_name) || Helpdesk::Tag.new(:name => updated_tag_name ,:account_id => self.account.id)
      }
      self.tags = new_tags
    end
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

  attr_accessor :import
  attr_accessible :name, :email, :password, :password_confirmation , :second_email, :job_title, :phone, :mobile, 
                  :twitter_id, :external_id, :description, :time_zone, :avatar_attributes,:user_role,:customer_id,:import_id,
                  :deleted , :fb_profile_id , :language, :address

  #Sphinx configuration starts
  define_index do
    indexes :name, :sortable => true
    indexes :email, :sortable => true
    indexes :description
    indexes :job_title
    indexes customer.name, :as => :company
    
    has account_id, deleted
    has SearchUtil::DEFAULT_SEARCH_VALUE, :as => :responder_id, :type => :integer
    has SearchUtil::DEFAULT_SEARCH_VALUE, :as => :group_id, :type => :integer

    #set_property :delta => :delayed
    set_property :field_weights => {
      :name         => 10,
      :email        => 10,
      :company      => 5,
      :job_title    => 4,
      :description  => 3
    }
  end
  #Sphinx configuration ends here..

  def signup!(params , portal=nil)   
    self.email = (params[:user][:email]).strip if params[:user][:email]
    self.name = params[:user][:name]
    self.phone = params[:user][:phone]
    self.mobile = params[:user][:mobile]
    self.second_email = params[:user][:second_email]
    self.twitter_id = params[:user][:twitter_id]
    self.external_id = params[:user][:external_id]
    self.description = params[:user][:description]
    self.customer_id = params[:user][:customer_id]
    self.job_title = params[:user][:job_title]
    self.user_role = params[:user][:user_role]
    self.time_zone = params[:user][:time_zone]
    self.import_id = params[:user][:import_id]
    self.fb_profile_id = params[:user][:fb_profile_id]
    self.language = params[:user][:language]
    self.address = params[:user][:address]
    self.update_tag_names(params[:user][:tags]) # update tags in the user object
    self.avatar_attributes=params[:user][:avatar_attributes] unless params[:user][:avatar_attributes].nil?
    self.deleted = true if email =~ /MAILER-DAEMON@(.+)/i
    return false unless save_without_session_maintenance
    deliver_activation_instructions!(portal,false, params[:email_config]) if (!deleted and !email.blank?)
    true
  end

  def signup(portal=nil)
    return false unless save_without_session_maintenance
    deliver_activation_instructions!(portal,false) if (!deleted and !email.blank?)
    true
  end

  def avatar_attributes=(av_attributes)
    return build_avatar(av_attributes) if avatar.nil?
    avatar.update_attributes(av_attributes)
  end
 
  def active?
    active
  end
  
  def has_email?
    !email.blank?
  end
  
  def activate!(params)
    self.active = true
    self.name = params[:user][:name]
    self.password = params[:user][:password]
    self.password_confirmation = params[:user][:password_confirmation]
    #self.openid_identifier = params[:user][:openid_identifier]
    save
  end

  def exist_in_db?
    !(id.blank?)
  end

  def has_no_credentials?
    self.crypted_password.blank? && active? && !account.sso_enabled? && !deleted && self.authorizations.empty? && self.twitter_id.blank? && self.fb_profile_id.blank? && self.external_id.blank?
  end

  # TODO move this to the "HelpdeskUser" model
  # when it is available
  has_many :subscriptions, 
    :class_name => 'Helpdesk::Subscription'
  
  has_many :subscribed_tickets, 
    :class_name => 'Helpdesk::Ticket',
    :source => 'ticket',
    :through => :subscriptions

  has_many :reminders, 
    :class_name => 'Helpdesk::Reminder',:dependent => :destroy
    
  has_many :tickets , :class_name => 'Helpdesk::Ticket' ,:foreign_key => "requester_id" 
  
  has_many :open_tickets, :class_name => 'Helpdesk::Ticket' ,:foreign_key => "requester_id",
  :conditions => {:status => [OPEN,PENDING]},
  :order => "created_at desc"
  
  has_one :agent , :class_name => 'Agent' , :foreign_key => "user_id", :dependent => :destroy
  has_one :full_time_agent, :class_name => 'Agent', :foreign_key => "user_id", :conditions => { 
      :occasional => false  } #no direct use, need this in account model for pass through.
  
  has_many :agent_groups , :class_name =>'AgentGroup', :foreign_key => "user_id" , :dependent => :destroy

  has_many :achieved_quests, :dependent => :delete_all

  has_many :quests, :through => :achieved_quests
  
  has_many :canned_responses , :class_name =>'Admin::CannedResponse' 
  
   
  #accepts_nested_attributes_for :agent
  accepts_nested_attributes_for :customer, :google_contacts  # Added to save the customer while importing user from google contacts.
  

  #Savage_beast changes start here
  #implement in your user model 
  def display_name
    to_s
  end

  #implement in your user model 
  def admin?
    user_role == USER_ROLES_KEYS_BY_TOKEN[:admin] ||  user_role == USER_ROLES_KEYS_BY_TOKEN[:account_admin]
  end
  
  def customer?
    user_role == USER_ROLES_KEYS_BY_TOKEN[:customer] || user_role == USER_ROLES_KEYS_BY_TOKEN[:client_manager]
  end
  alias :is_customer :customer?
  
  def agent?
    !customer?
  end
  alias :is_agent :agent?
  
  def account_admin?
    user_role == USER_ROLES_KEYS_BY_TOKEN[:account_admin]
  end
  
  def client_manager?
    user_role == USER_ROLES_KEYS_BY_TOKEN[:client_manager]
  end
  alias :is_client_manager :client_manager?

  def supervisor?
    user_role == USER_ROLES_KEYS_BY_TOKEN[:supervisor]
  end

  def first_login?
    login_count <= 2
  end
  
  #Savage_beast changes end here

  #Search display
  def self.search_display(user)
    "#{user.excerpts.name} - #{user.excerpts.email}"
  end
  #Search display ends here

  ##Authorization copy starts here
  def role
    @role ||= Helpdesk::ROLES[USER_ROLES_SYMBOL_BY_KEY[user_role]] || Helpdesk::ROLES[:customer]
  end
  
  def permission?(p)
    role[:permissions][p]
  end
  
  def name_details #changed name_email to name_details
    return "#{name} <#{email}>" unless email.blank?
    return "#{name} (#{phone})" unless phone.blank?
    return "#{name} (#{mobile})" unless mobile.blank?
    return "@#{twitter_id}" unless twitter_id.blank?

    name
  end

  def self.find_all_by_permission(account, p)
    #self.find(:all).select { |a| a.permission?(p) }
    self.find_all_by_account_id(account).select { |a| a.permission?(p) }
  end
  ##Authorization copy ends here
  
  def url_protocol
    account.ssl_enabled? ? 'https' : 'http'
  end
  
  def set_time_zone
    self.time_zone = account.time_zone if time_zone.nil? #by Shan temp
  end
  
  def set_language
    self.language = account.language if language.nil? 
  end
  
  def to_s
    name.blank? ? email : name
  end
  
  def to_liquid
    UserDrop.new self
  end
  
  def has_manage_forums?
      self.permission?(:manage_forums)
  end
  
  def has_manage_solutions?
    self.permission?(:manage_tickets)
  end
  

  def has_company?
    customer? && customer
  end

  def is_not_deleted?
    logger.debug "not ::deleted ?:: #{!self.deleted}"
    !self.deleted
  end
  
  def occasional_agent?
    agent && agent.occasional
  end
  
  def day_pass_granted_on(start_time = DayPassUsage.start_time) #Revisit..
    day_pass_usages.on_the_day(start_time).first
  end
  
  def self.filter(letter, page, state = "verified", per_page = 50)
    paginate :per_page => per_page, :page => page,
             :conditions => filter_condition(state, letter) ,
             :order => 'name'
  end

  def self.filter_condition(state, letter)
    case state
      when "verified", "unverified"
        [ ' name like ? and deleted = ? and active = ? and email is not ? ', "#{letter}%", false , state.eql?("verified"), nil ]
      when "deleted", "all"
        [ ' name like ? and deleted = ? ', "#{letter}%", state.eql?("deleted") ]
    end                                      
  end
  
  def get_info
    (email) || (twitter_id) || (external_id)
  end
  
  def twitter_style_id
    "@#{twitter_id}"
  end
  
  def can_view_all_tickets?
    self.permission?(:manage_tickets) && agent.all_ticket_permission
  end
  
  def group_ticket_permission
    self.permission?(:manage_tickets) && agent.group_ticket_permission
  end
  
  def has_ticket_permission? ticket
    (can_view_all_tickets?) or (ticket.responder == self ) or (group_ticket_permission && (ticket.group_id && (agent_groups.collect{|ag| ag.group_id}.insert(0,0)).include?( ticket.group_id))) 
  end
  
  def restricted?
    !can_view_all_tickets?
  end

  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml,:root=>options[:root], :skip_instruct => true,:only => [:id,:name,:email,:created_at,:updated_at,:active,:customer_id,:job_title,
                                                              :phone,:mobile,:twitter_id,:description,:time_zone,:deleted,
                                                              :user_role,:fb_profile_id,:external_id,:language,:address]) 
  end
  
  def company_name
    customer.name unless customer.nil?
  end

  def has_company?
    customer? && customer
  end

  def to_mob_json
    options = { 
      :methods => [ :original_avatar, :medium_avatar, :avatar_url, :is_agent, :is_customer, :recent_tickets, :is_client_manager, :company_name ],
      :only => [ :id, :name, :email, :mobile, :phone, :job_title, :twitter_id, :fb_profile_id, :external_id ]
    }
    to_json options
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
  
  def make_customer
    return if customer?
    
    update_attributes({:user_role => USER_ROLES_KEYS_BY_TOKEN[:customer], :deleted => false})
    agent.destroy
  end

  protected
    def set_account_id_in_children
      self.avatar.account_id = account_id unless avatar.nil?
  end

  def set_contact_name 
    if self.name.blank?
      self.name = (self.email.split("@")[0]).capitalize
    end
  end
 
 def set_default_role
   self.user_role = USER_ROLES_KEYS_BY_TOKEN[:customer] if self.user_role.blank?
 end

 def set_company_name
   if (self.customer_id.nil? && self.email)      
       email_domain =  self.email.split("@")[1]
       cust = account.customers.domains_like(email_domain).first
       self.customer_id = cust.id unless cust.nil?    
   end
 end
 
 def drop_authorization
   authorizations.each do |auth|
     auth.destroy
   end 
 end
 
  def self.find_by_email_or_name(value)
    conditions = {}
    if value =~ /(\b[-a-zA-Z0-9.'’_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b)/
      conditions[:email] = value
    else
      conditions[:name] = value
    end
    user = self.find(:first, :conditions => conditions)
    user
  end

  def self.find_by_an_unique_id(options = {})
    options.delete_if { |key, value| value.blank? }
    
    #return self.find(options[:id]) if options.key?(:id)
    return self.find_by_email(options[:email]) if options.key?(:email)
    return self.find_by_twitter_id(options[:twitter_id]) if options.key?(:twitter_id)
    return self.find_by_external_id(options[:external_id]) if options.key?(:external_id)
  end 
  
  private

    def account_admin_updated?
      user_role_changed? && account_admin?
    end

    def update_admin_in_crm
      Resque.enqueue(CRM::AddToCRM::UpdateAdmin, self.id)
    end

    def bakcup_user_changes
      @all_changes = self.changes.clone
      @all_changes.symbolize_keys!
    end

    def user_role_updated?
      @all_changes.has_key?(:user_role)
    end
    
    def update_admin_to_billing
      Resque.enqueue(Billing::AddToBilling::UpdateAdmin, self.id)
    end
end
