class User < ActiveRecord::Base
  include ActionController::UrlWriter
  include SavageBeast::UserInit
  include SentientUser
  
  USER_ROLES = [
    [ :admin,       "Admin",            1 ],
    [ :poweruser,   "Power User",       2 ],
    [ :customer,    "Customer",         3 ],
    [ :account_admin,"Account admin",   4 ]
   ]

  USER_ROLES_OPTIONS = USER_ROLES.map { |i| [i[1], i[2]] }
  USER_ROLES_NAMES_BY_KEY = Hash[*USER_ROLES.map { |i| [i[2], i[1]] }.flatten]
  USER_ROLES_KEYS_BY_TOKEN = Hash[*USER_ROLES.map { |i| [i[0], i[2]] }.flatten]
  USER_ROLES_SYMBOL_BY_KEY = Hash[*USER_ROLES.map { |i| [i[2], i[0]] }.flatten]
  
  belongs_to :account
  belongs_to :customer
  
  has_many :authorizations, :dependent => :destroy
  
  validates_uniqueness_of :user_role, :scope => :account_id, :if => Proc.new { |user| user.user_role  == USER_ROLES_KEYS_BY_TOKEN[:account_admin] }
  
  has_one :avatar,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy

  before_create :set_time_zone , :set_company_name
  before_save :set_account_id_in_children , :set_contact_name
  
  named_scope :contacts, :conditions => ["user_role=?", USER_ROLES_KEYS_BY_TOKEN[:customer]]

  acts_as_authentic do |c|    
    c.validations_scope = :account_id
    c.validates_length_of_password_field_options = {:on => :update, :minimum => 4, :if => :has_no_credentials? }
    c.validates_length_of_password_confirmation_field_options = {:on => :update, :minimum => 4, :if => :has_no_credentials?}    
    #The following is a part to validate email only if its not deleted
    c.merge_validates_format_of_email_field_options  :if =>:is_not_deleted?
    c.merge_validates_length_of_email_field_options :if =>:is_not_deleted?
    c.merge_validates_uniqueness_of_email_field_options :if =>:is_not_deleted?
   
    
  end
  
  attr_accessible :name, :email, :password, :password_confirmation , :second_email, :job_title, :phone, :mobile, :twitter_id, :description, :time_zone, :avatar_attributes,:user_role,:customer_id,:import_id,:deleted
  
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

  def signup!(params)
    self.email = params[:user][:email]
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
    
    
    self.avatar_attributes=params[:user][:avatar_attributes] unless params[:user][:avatar_attributes].nil?
   
    return false unless save_without_session_maintenance
    deliver_activation_instructions! unless deleted
  end
  
  def avatar_attributes=(av_attributes)
    return build_avatar(av_attributes) if avatar.nil?
    avatar.update_attributes(av_attributes)
  end

 
  def active?
    active
  end
  
  def activate!(params)
    self.active = true
    self.name = params[:user][:name]
    self.password = params[:user][:password]
    self.password_confirmation = params[:user][:password_confirmation]
    #self.openid_identifier = params[:user][:openid_identifier]
    save
  end
  
  def has_no_credentials?
    self.crypted_password.blank? && active? && !deleted && self.authorizations.empty?
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
    :class_name => 'Helpdesk::Reminder'
    
  has_many :tickets , :class_name => 'Helpdesk::Ticket' ,:foreign_key => "requester_id"
  
  has_one :agent , :class_name => 'Agent' , :foreign_key => "user_id"
  
  has_many :agent_groups , :class_name =>'AgentGroup', :foreign_key => "user_id" , :dependent => :destroy
  
   
  #accepts_nested_attributes_for :agent
  
  

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
    user_role == USER_ROLES_KEYS_BY_TOKEN[:customer]
  end
  
  def agent?
    user_role == USER_ROLES_KEYS_BY_TOKEN[:poweruser]
  end
  
  def account_admin?
    user_role == USER_ROLES_KEYS_BY_TOKEN[:account_admin]
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
    "#{name} <#{email}>"
  end

  def self.find_all_by_permission(account, p)
    #self.find(:all).select { |a| a.permission?(p) }
    self.find_all_by_account_id(account).select { |a| a.permission?(p) }
  end
  ##Authorization copy ends here
  
  def deliver_password_reset_instructions! #Do we need delayed_jobs here?! by Shan
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
          'helpdesk_name' => account.helpdesk_name, 'password_reset_url' => edit_password_reset_url(perishable_token, :host => account.host)))
  end
  
  def deliver_activation_instructions! #Need to refactor this.. Almost similar structure with the above one.
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
          'helpdesk_name' => account.helpdesk_name, 'activation_url' => register_url(perishable_token, :host => account.host)), 
        :subject => "#{account.helpdesk_name} user activation")
  end
  
  def deliver_contact_activation
    unless active?
      reset_perishable_token!
  
      e_notification = account.email_notifications.find_by_notification_type(EmailNotification::USER_ACTIVATION)
      UserNotifier.send_later(:deliver_user_activation, self, 
          :email_body => Liquid::Template.parse(e_notification.requester_template).render('contact' => self, 
            'helpdesk_name' => account.helpdesk_name, 'activation_url' => register_url(perishable_token, :host => account.host)), 
          :subject => "#{account.helpdesk_name} user activation")
    end
  end
  
  def set_time_zone
    self.time_zone = account.time_zone if time_zone.nil? #by Shan temp
  end
  
  def to_s
    name.empty? ? email : name
  end
  
  def to_liquid
    to_ret = { 
      "name"  => to_s,
      "email" => email
    }
    
    to_ret["company_name"] = customer.name if customer_id
    
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

  protected
    def set_account_id_in_children
      self.avatar.account_id = account_id unless avatar.nil?
  end
  
  def set_contact_name
   
    if self.name.empty?
      self.name = (self.email.split("@")[0]).capitalize
    end
   
 end
 
 def set_company_name
   
   if (self.customer_id.nil? && self.email)      
       email_domain =  self.email.split("@")[1]
       cust = Customer.account_id_like(account_id).domains_like(email_domain).first
       self.customer_id = cust.id unless cust.nil?    
     
   end
   
 end
 
 
  
end
