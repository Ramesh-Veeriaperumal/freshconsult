class User < ActiveRecord::Base
  include SavageBeast::UserInit
  
  belongs_to :account
  belongs_to :customer
  
  before_create :set_time_zone

  acts_as_authentic do |c|
    c.validations_scope = :account_id
    c.validates_length_of_password_field_options = {:on => :update, :minimum => 4, :if => :has_no_credentials?}
    c.validates_length_of_password_confirmation_field_options = {:on => :update, :minimum => 4, :if => :has_no_credentials?}
  end
  
  attr_accessible :name, :email, :password, :password_confirmation , :second_email, :job_title, :phone, :mobile, :twitter_id, :description, :customer_id , :role_token, :time_zone 

  def signup!(params)
    self.email = params[:user][:email]
    self.name = params[:user][:name]
    self.role_token = params[:user][:role_token]
    self.phone = params[:user][:phone]
    self.mobile = params[:user][:mobile]
    self.second_email = params[:user][:second_email]
    self.twitter_id = params[:user][:twitter_id]
    self.description = params[:user][:description]
    self.customer_id = params[:user][:customer_id]
    self.job_title = params[:user][:job_title]
   
    save_without_session_maintenance
    deliver_activation_instructions!
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
    self.crypted_password.blank? #&& self.openid_identifier.blank?
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
  
  has_many :agents , :class_name => 'Agent' , :foreign_key => "user_id"
  
  accepts_nested_attributes_for :agents
  
  

  #Savage_beast changes start here
  #implement in your user model 
  def display_name
    name
  end
        
  #implement in your user model 
#  def admin?
#    false
#  end

  #Savage_beast changes end here

#To do work for password reset. By Shan
#  def deliver_password_reset_instructions!  
#    reset_perishable_token!
#    UserNotifier.password_reset_instructions(self).deliver
#  end

  ##Authorization copy starts here
  def role
    @role ||= Helpdesk::ROLES[role_token.to_sym] || Helpdesk::ROLES[:customer]
  end
  
  def permission?(p)
    role[:permissions][p]
  end

  def self.find_all_by_permission(account, p)
    #self.find(:all).select { |a| a.permission?(p) }
    self.find_all_by_account_id(account).select { |a| a.permission?(p) }
  end
  ##Authorization copy ends here
  
  def deliver_activation_instructions!
    reset_perishable_token!
    UserNotifier.send_later(:deliver_activation_instructions, self)
  end
 
  def deliver_activation_confirmation!
    reset_perishable_token!
    UserNotifier.deliver_activation_confirmation(self)
  end
  
  def set_time_zone
    self.time_zone = account.time_zone if time_zone.nil? #by Shan temp
  end
  
end
