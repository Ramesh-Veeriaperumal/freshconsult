class User < ActiveRecord::Base

  before_create :set_time_zone , :set_company_name
  #user_email callbacks
  # before_validation :assign_user_email, :if => :email_required?
  # after_validation :set_primary_email, :on => :create
  #end
  before_create :set_language, :unless => :created_from_email
  before_save :set_customer_privilege, :if => :customer?
  before_create :populate_privileges, :if => :helpdesk_agent?
  before_update :populate_privileges, :if => :roles_changed?
  before_update :destroy_user_roles, :delete_freshfone_user,:remove_user_mobile_registrations, :if => :deleted?
  before_save :set_contact_name, :check_email_value, :update_user_related_changes
  after_create :update_user_email, :if => [:email_available?, :user_emails_migrated?, :no_multiple_user_emails] #for user email delta
  after_update :drop_authorization , :if => [:email_changed?, :no_multiple_user_emails]
  after_update :change_user_email, :if => [:email_changed?, :user_emails_migrated?, :no_multiple_user_emails] #for user email delta
  after_update :update_verified, :if => [:active_changed?, :email_available?, :user_emails_migrated?, :no_multiple_user_emails] #for user email delta
  before_update :make_inactive, :if => [:email_changed?, :no_multiple_user_emails]
  after_commit :send_activation_email, on: :update, :if => [:email_updated?, :no_multiple_user_emails]
  # before_save :set_primary_email, :if => :no_primary_email
  # before_save :remove_duplicate_emails

  after_commit ->(obj) { obj.clear_agent_list_cache }, :if => :agent?
  after_commit ->(obj) { obj.clear_agent_list_cache }, on: :update, :if => :helpdesk_agent_updated?

  after_commit :clear_agent_name_cache
  after_commit :subscribe_event_create, on: :create, :if => :allow_api_webhook?
  after_commit :subscribe_event_update, on: :update, :if => :allow_api_webhook?
  
  after_commit :update_search_index, on: :update, :if => :company_info_updated?

  before_update :backup_user_changes
  before_update :clear_redis_for_agent

  def set_time_zone
    self.time_zone = account.time_zone if time_zone.nil? #by Shan temp
  end

  def no_primary_email
    self.actual_email.blank? and !no_multiple_user_emails
  end

  def remove_duplicate_emails
    email_array = []
    self.user_emails.select(&:new_record?).each do |ue|
      ue.delete if email_array.include?(ue.email)
      email_array << ue.email
    end
  end

  def set_customer_privilege
    # If the customer has only client_manager privilege and is not associated with
    # any other privilege then dont set privileges to "0"
    if(!privilege?(:client_manager) || !(abilities.length == 1))
      destroy_user_roles
    end
  end

  def populate_privileges
    self.privileges = union_privileges(self.roles).to_s
    @role_change_flag = false
    true
  end

  def email_available?
    self[:email].present?
  end

  def destroy_user_roles
    self.privileges = "0"
    self.roles.clear
  end

  def check_email_value
    if !email_available?
      self.email = nil
    end
  end

  def set_language
    self.language = account.language if language.nil? 
  end

  protected

  def set_contact_name 
    if self.name.blank? && email_obtained.present?
      self.name = (email_obtained.split("@")[0]).capitalize
    end
  end

  def email_obtained
    self[:email] || self.actual_email
  end

  def update_user_related_changes
    @model_changes = self.changes.clone
    # @model_changes.symbolize_keys!
  end

  def set_company_name
   if (self.company_id.nil? && self.email)      
       email_domain =  self.email.split("@")[1]
       comp = account.companies.domains_like(email_domain).first
       self.company_id = comp.id unless comp.nil?    
   end
  end

  def drop_authorization
    authorizations.each do |auth|
      auth.destroy
    end 
  end

  def make_inactive
    self.active = false
    true
  end

  def send_activation_email
    self.deliver_activation_instructions!(account.main_portal,false)
  end

  def assign_user_email
    self.user_emails.build unless user_emails.present? or no_multiple_user_emails
  end

  def set_primary_email
    if self.user_emails.present?
      self.user_emails.reject(&:marked_for_destruction?).first.primary_role = true unless self.user_emails.reject(&:marked_for_destruction?).first.nil?
      self.primary_email = self.user_emails.first
    end
  end

  def update_user_email
    # for user email delta
    self.create_primary_email({:email => self[:email], :primary_role => true, :verified => active, :account_id => self.account_id}) unless !email_available? or user_emails.present?
  end

  def change_user_email
    # for user email delta
    if primary_email
      if email_available?
        primary_email.update_attributes({:email => self[:email]})
      else
        primary_email.destroy
      end
    else
      create_primary_email({:email => self[:email], :primary_role => true, :verified => active}) if email_available?
    end
  end

  def update_verified
    #for user email delta
    if primary_email
      if active?
        primary_email.update_attributes({:verified => true})
      else
        primary_email.update_attributes({:verified => false})
      end
    end
  end

  def delete_freshfone_user
    freshfone_user.destroy if freshfone_user
  end


end
