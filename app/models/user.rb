class User < ActiveRecord::Base
  include SavageBeast::UserInit
  
  belongs_to :account

  acts_as_authentic do |c|
    c.validations_scope = :account_id
    c.validates_length_of_password_field_options = {:on => :update, :minimum => 4, :if => :has_no_credentials?}
    c.validates_length_of_password_confirmation_field_options = {:on => :update, :minimum => 4, :if => :has_no_credentials?}
  end
  
  attr_accessible :name, :email, :password, :password_confirmation

  def signup!(params)
    self.email = params[:user][:email]
    self.name = params[:user][:name]
    save_without_session_maintenance
    Helpdesk::Authorization.create(:user => self, :role_token => "admin") #by Shan temp
  end
 
  def active?
    active
  end
  
  def activate!(params)
    self.active = true
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
  
  def deliver_activation_instructions!
    reset_perishable_token!
    UserNotifier.deliver_activation_instructions(self)
  end
 
  def deliver_activation_confirmation!
    reset_perishable_token!
    UserNotifier.deliver_activation_confirmation(self)
  end
end
