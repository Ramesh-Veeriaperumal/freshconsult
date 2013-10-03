class User < ActiveRecord::Base

	before_validation :downcase_email
  before_create :set_time_zone , :set_company_name , :set_language
  before_save :set_customer_privilege, :if => :customer?
  before_create :populate_privileges, :if => :helpdesk_agent?
  before_update :populate_privileges, :if => :roles_changed?
  before_update :destroy_user_roles, :if => :deleted?
  before_save :set_contact_name, :check_email_value
  #after_create :update_user_email, :if => [:has_email?, :user_emails_migrated?] #for user email delta
  after_update :drop_authorization , :if => :email_changed?
  #after_update :change_user_email, :if => [:email_changed?, :user_emails_migrated?] #for user email delta
  #after_update :update_verified, :if => [:active_changed?, :has_email?, :user_emails_migrated?] #for user email delta

  after_commit_on_create :clear_agent_list_cache, :if => :agent?
  after_commit_on_update :clear_agent_list_cache, :if => :agent?
  after_commit_on_destroy :clear_agent_list_cache, :if => :agent?
  after_commit_on_update :clear_agent_list_cache, :if => :helpdesk_agent_updated?
  
  before_update :bakcup_user_changes, :clear_redis_for_agent
  after_commit_on_update :update_search_index, :if => :customer_id_updated?

  def downcase_email
    self.email = email.downcase if email
  end

  def set_time_zone
    self.time_zone = account.time_zone if time_zone.nil? #by Shan temp
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

  def destroy_user_roles
    self.privileges = "0"
    self.roles.clear
  end

  def check_email_value
    if email.blank?
      self.email = nil
    end
  end

  def set_language
    self.language = account.language if language.nil? 
  end

  protected

  def set_contact_name 
    if self.name.blank? && email
      self.name = (self.email.split("@")[0]).capitalize
    end
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

  # def update_user_email
  #   # for user email delta
  #   create_user_email({:email => email, :primary_role => true, :verified => active}) unless user_email
  # end

  # def change_user_email
  #   # for user email delta
  #   if user_email
  #     if has_email?
  #       user_email.update_attributes({:email => email})
  #     else
  #       user_email.destroy
  #     end
  #   else
  #     create_user_email({:email => email, :primary_role => true, :verified => active}) if has_email?
  #   end
  # end

  # def update_verified
  #   #for user email delta
  #   if active?
  #     user_email.update_attributes({:verified => true})
  #   else
  #     user_email.update_attributes({:verified => false})
  #   end
  # end


end