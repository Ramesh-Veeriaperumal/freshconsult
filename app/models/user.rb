class User < ActiveRecord::Base
  include ActionController::UrlWriter
  include SavageBeast::UserInit
  include SentientUser
  
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
  EMAIL_REGEX = /(\A[A-Z0-9_\.%\+\-\'=]+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,4}|museum|travel)\z)/i
  
  belongs_to :account
  belongs_to :customer
  
  has_many :authorizations, :dependent => :destroy
  has_many :votes, :dependent => :destroy
  
  has_many :time_sheets , :class_name =>'Helpdesk::TimeSheet' , :dependent => :destroy
  
  validates_uniqueness_of :user_role, :scope => :account_id, :if => Proc.new { |user| user.user_role  == USER_ROLES_KEYS_BY_TOKEN[:account_admin] }
  validates_uniqueness_of :twitter_id, :scope => :account_id, :allow_nil => true, :allow_blank => true
  
  has_many :tag_uses,
    :as => :taggable,
    :class_name => 'Helpdesk::TagUse',
    :dependent => :destroy

  has_many :tags, 
    :class_name => 'Helpdesk::Tag',
    :through => :tag_uses

  has_one :avatar,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy

  before_create :set_time_zone , :set_company_name , :set_language
  before_save :set_account_id_in_children , :set_contact_name, :check_email_value , :set_default_role
  after_update :drop_authorization , :if => :email_changed?
  
  named_scope :contacts, :conditions => ["user_role in (#{USER_ROLES_KEYS_BY_TOKEN[:customer]}, #{USER_ROLES_KEYS_BY_TOKEN[:client_manager]})" ]
  named_scope :technicians, :conditions => ["user_role not in (#{USER_ROLES_KEYS_BY_TOKEN[:customer]}, #{USER_ROLES_KEYS_BY_TOKEN[:client_manager]})"]
  named_scope :visible, :conditions => { :deleted => false }

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
    (is_not_deleted?) and (twitter_id.blank? || !email.blank?) and (fb_profile_id.blank? || !email.blank?)
  end

  def add_tag(tag_id)
    unless tag_id.blank?
      tag_use = Helpdesk::TagUse.new :tag_id=>tag_id
      tag_use.taggable_id=self.id
      tag_use.taggable_type="User"
      self.tag_uses.push tag_use
    end
  end

  def update_tag_names(csv_tag_names)
    updated_tag_names = csv_tag_names.split(",")
    new_tags = []
    updated_tag_names.each { |updated_tag_name|
      updated_tag_name = updated_tag_name.strip
      # TODO Below line executes query for every iteration.  Better to use some cached objects.
      new_tags.push Helpdesk::Tag.find_by_name_and_account_id(updated_tag_name, self.account.id) || Helpdesk::Tag.new(:name => updated_tag_name ,:account_id => self.account.id)
    }
    self.tags = new_tags
  end

  def tagged?(tag_id)
    unless tag_id.blank?
      # To avoid DB query.
      self.tags.each {|tag|
        return true if tag.id == tag_id
      }
      # Check the tag_uses that are not yet committed in the DB
      self.taguses.each {|tag_use|
        return true if tag_use.tag_id == tag_id
      }
    end
    return false
  end

  attr_accessor :import, :google_group_ids
  attr_accessible :name, :email, :password, :password_confirmation , :second_email, :job_title, :phone, :mobile, 
                  :twitter_id, :description, :time_zone, :avatar_attributes,:user_role,:customer_id,:import_id,
                  :deleted , :fb_profile_id , :language, :address

  #Sphinx configuration starts
  define_index do
    indexes :name, :sortable => true
    indexes :email, :sortable => true
    indexes :description
    indexes :job_title
    indexes customer.name, :as => :company
    
    has account_id, deleted
    
    set_property :delta => :delayed
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
    self.description = params[:user][:description]
    self.customer_id = params[:user][:customer_id]
    self.job_title = params[:user][:job_title]
    self.user_role = params[:user][:user_role]
    self.time_zone = params[:user][:time_zone]
    self.import_id = params[:user][:import_id]
    self.fb_profile_id = params[:user][:fb_profile_id]
    self.language = params[:user][:language]
    
    
    self.avatar_attributes=params[:user][:avatar_attributes] unless params[:user][:avatar_attributes].nil?
    signup   
  end

  def signup
    return false unless save_without_session_maintenance
    deliver_activation_instructions!(portal) if (!deleted and !email.blank?)
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

  def is_google_contact?
    google_id.blank?
  end

  def exist_in_db?
    !(id.blank?)
  end

  def has_no_credentials?
    self.crypted_password.blank? && active? && !account.sso_enabled? && !deleted && self.authorizations.empty? && self.twitter_id.blank?
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
    
  has_many :tickets , :class_name => 'Helpdesk::Ticket' ,:foreign_key => "requester_id" , :dependent => :destroy
  
  has_many :open_tickets, :class_name => 'Helpdesk::Ticket' ,:foreign_key => "requester_id",
  :conditions => {:status => [TicketConstants::STATUS_KEYS_BY_TOKEN[:open],TicketConstants::STATUS_KEYS_BY_TOKEN[:pending]]},
  :order => "created_at desc"
  
  has_one :agent , :class_name => 'Agent' , :foreign_key => "user_id", :dependent => :destroy
  
  has_many :agent_groups , :class_name =>'AgentGroup', :foreign_key => "user_id" , :dependent => :destroy
  
  has_many :canned_responses , :class_name =>'Admin::CannedResponse' 
  
   
  #accepts_nested_attributes_for :agent
  accepts_nested_attributes_for :customer  # Added to save the customer while importing user from google contacts.
  

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
  
  def agent?
    user_role == USER_ROLES_KEYS_BY_TOKEN[:poweruser]
  end
  
  def account_admin?
    user_role == USER_ROLES_KEYS_BY_TOKEN[:account_admin]
  end
  
  def client_manager?
    user_role == USER_ROLES_KEYS_BY_TOKEN[:client_manager]
  end
  
  def supervisor?
    user_role == USER_ROLES_KEYS_BY_TOKEN[:supervisor]
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
  
  def name_email
    "#{name} <#{email}>" unless email.nil?
  end

  def self.find_all_by_permission(account, p)
    #self.find(:all).select { |a| a.permission?(p) }
    self.find_all_by_account_id(account).select { |a| a.permission?(p) }
  end
  ##Authorization copy ends here
  
  def deliver_password_reset_instructions!(portal) #Do we need delayed_jobs here?! by Shan
    portal ||= account.main_portal
    reset_perishable_token!
    
    e_notification = account.email_notifications.find_by_notification_type(EmailNotification::PASSWORD_RESET)
    if customer?
      template = e_notification.requester_template
      user_key = 'contact'
    else
      template = e_notification.agent_template
    end
    
    UserNotifier.deliver_password_reset_instructions(self, 
        :email_body => Liquid::Template.parse(template).render((user_key ||= 'agent') => self, 
          'helpdesk_name' => (!portal.name.blank?) ? portal.name : account.portal_name , 'password_reset_url' => edit_password_reset_url(perishable_token, :host => (!portal.portal_url.blank?) ? portal.portal_url : account.host)) , 
          :subject => "#{ (!portal.name.blank?) ? portal.name : account.portal_name} password reset instructions" ,:reply_email => portal.product.friendly_email)
  end
  
  def deliver_activation_instructions!(portal) #Need to refactor this.. Almost similar structure with the above one.
    portal ||= account.main_portal
    reset_perishable_token!

    e_notification = account.email_notifications.find_by_notification_type(EmailNotification::USER_ACTIVATION)
    if customer?
      return unless e_notification.requester_notification?
      template = e_notification.requester_template
      user_key = 'contact'
    else
      template = e_notification.agent_template
    end
    
    UserNotifier.send_later(:deliver_user_activation, self, 
        :email_body => Liquid::Template.parse(template).render((user_key ||= 'agent') => self, 
          'helpdesk_name' =>  (!portal.name.blank?) ? portal.name : account.portal_name, 'activation_url' => register_url(perishable_token, :host => (!portal.portal_url.blank?) ? portal.portal_url : account.host)), 
        :subject => "#{ (!portal.name.blank?) ? portal.name : account.portal_name} user activation" , :reply_email => portal.product.friendly_email)
  end
  
  def deliver_contact_activation(portal)
    portal ||= account.main_portal
    unless active?
      reset_perishable_token!
  
      e_notification = account.email_notifications.find_by_notification_type(EmailNotification::USER_ACTIVATION)
      UserNotifier.send_later(:deliver_user_activation, self, 
          :email_body => Liquid::Template.parse(e_notification.requester_template).render('contact' => self, 
            'helpdesk_name' =>  (!portal.name.blank?) ? portal.name : account.portal_name , 'activation_url' => register_url(perishable_token, :host => (!portal.portal_url.blank?) ? portal.portal_url : account.host)), 
          :subject => "#{ (!portal.name.blank?) ? portal.name : account.portal_name} user activation" , :reply_email => portal.product.friendly_email)
    end
  end
  
  def deliver_account_admin_activation
      UserNotifier.send_later(:deliver_account_admin_activation,self)
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
    to_ret = { 
      "id"   => id,
      "name"  => to_s,
      "email" => email,
      "phone" => phone,
      "mobile" => mobile,
      "job_title" => job_title,
      "user_role" => user_role,
      "time_zone" => time_zone,
    }
    
    to_ret["company_name"] = customer.name if customer
    
    to_ret
  end
  
  def has_manage_forums?
      self.permission?(:manage_forums)
  end
  
  def has_manage_solutions?
    self.permission?(:manage_tickets)
  end
  
  def is_not_deleted?
    logger.debug "not ::deleted ?:: #{!self.deleted}"
    !self.deleted
  end
  
  def self.filter(letter, page)
  paginate :per_page => 10, :page => page,
           :conditions => ['name like ?', "#{letter}%"],
           :order => 'name'
  end
  
  def get_info
    (email) || (twitter_id)
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
  
    def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:except => [:account_id,:crypted_password,:password_salt,:perishable_token,:persistence_token,:single_access_token]) 
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
 
 
 
 
  
end
