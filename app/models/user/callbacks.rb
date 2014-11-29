class User < ActiveRecord::Base

  before_validation :discard_blank_email, :unless => :email_available?
  
  before_create :set_time_zone , :set_company_name
  before_create :set_language, :unless => :created_from_email
  before_create :populate_privileges, :if => :helpdesk_agent?

  before_update :populate_privileges, :if => :roles_changed?
  before_update :destroy_user_roles, :delete_freshfone_user,:remove_user_mobile_registrations, :if => :deleted?
  before_update :backup_user_changes, :clear_redis_for_agent

  before_save :set_contact_name, :update_user_related_changes
  before_save :set_customer_privilege, :if => :customer?

  after_commit :clear_agent_name_cache

  after_commit_on_create :clear_agent_list_cache, :if => :agent?
  after_commit_on_create :subscribe_event_create, :if => :allow_api_webhook?

  after_commit_on_update :clear_agent_list_cache, :if => :agent?
  after_commit_on_update :clear_agent_list_cache, :if => :helpdesk_agent_updated?
  after_commit_on_update :subscribe_event_update, :if => :allow_api_webhook?
  after_commit_on_update :update_search_index, :if => :company_info_updated?
  after_commit_on_update :discard_contact_field_data, :if => :made_helpdesk_agent?

  after_commit_on_destroy :clear_agent_list_cache, :if => :agent?

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

  def set_language
    self.language = account.language if language.nil? 
  end

  def discard_contact_field_data
    self.flexifield.destroy
  end

  protected

  def discard_blank_email
    self[:email] = nil
  end
  
  def set_contact_name 
    if self.name.blank? && email_obtained.present?
      self.name = (email_obtained.split("@")[0]).capitalize
    end
  end

  def email_obtained
    self[:email]
  end

  def update_user_related_changes
    @model_changes = self.changes.clone
    @model_changes.symbolize_keys!
  end

  def set_company_name
   if (self.company_id.nil? && self.email)      
       email_domain =  self.email.split("@")[1]
       comp = account.companies.domains_like(email_domain).first
       self.company_id = comp.id unless comp.nil?    
   end
  end

  def delete_freshfone_user
    freshfone_user.destroy if freshfone_user
  end

  def made_helpdesk_agent?
    @model_changes[:helpdesk_agent] == [false, true]
  end


end
