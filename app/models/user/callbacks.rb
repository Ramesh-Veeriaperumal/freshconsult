class User < ActiveRecord::Base

  before_validation :discard_blank_email, :unless => :email_available?
  before_validation :set_password, :if => [:active?, :email_available?, :no_password?]
  before_validation :remove_white_space
  
  before_create :set_company_name, :unless => :helpdesk_agent?
  before_create :decode_name
  before_create :populate_privileges, :if => :helpdesk_agent?

  before_update :populate_privileges, :if => :roles_changed?
  before_update :destroy_user_roles, :delete_freshfone_user,:remove_user_mobile_registrations, :delete_user_authorizations, :if => :deleted?

  before_update :backup_user_changes, :clear_redis_for_agent

  after_update  :send_alert_email, :if => :email_changed?

  before_save :set_time_zone, :set_default_company
  before_save :set_language, :unless => :created_from_email
  before_save :set_contact_name, :update_user_related_changes
  before_save :set_customer_privilege, :set_contractor_privilege, :if => :customer?
  before_save :restrict_domain, :if => :email_changed?
  before_save :sanitize_contact_name, :backup_customer_id

  after_commit :clear_agent_caches, on: :create, :if => :agent?
  after_commit :update_agent_caches, on: :update

  after_commit :subscribe_event_create, on: :create, :if => :allow_api_webhook?

  after_commit :subscribe_event_update, on: :update, :if => :allow_api_webhook?
  
  after_commit :inst_app_business_event_create, on: :create, :if => :allow_inst_app_business_rule?
  
  #after_commit :discard_contact_field_data, on: :update, :if => [:helpdesk_agent_updated?, :agent?]
  after_commit :delete_forum_moderator, on: :update, :if => :helpdesk_agent_updated?
  after_commit :deactivate_monitorship, on: :update, :if => :blocked_deleted?
  after_commit :remove_user_mobile_registrations, on: :update, :if => :password_updated?

  # Callbacks will be executed in the order in which they have been included. 
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher 

  def blocked_deleted?
    (deleted_updated? && self.deleted) || (blocked_updated? && self.blocked)
  end
  
  def deactivate_monitorship
    Community::DeactivateMonitorship.perform_async(self.id)
  end

  def update_agent_caches
    clear_agent_caches if (agent? or helpdesk_agent_updated?)
  end

  def set_time_zone
    self.time_zone = account.time_zone if time_zone.nil? || validate_time_zone(time_zone) #by Shan temp
  end

  def set_contractor_privilege
    self.privileges = company_ids.length > 1 ? Role.privileges_mask([:contractor]).to_s : "0" \
      if has_multiple_companies_feature?
  end

  def set_customer_privilege
    # If the customer has only client_manager privilege and is not associated with
    # any other privilege then dont set privileges to "0"
    if((!company_client_manager? && !privilege?(:contractor)) || (abilities.length == 1))
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
    self.language = account.language if language.nil? || validate_language(language)
  end

  def discard_contact_field_data
    self.flexifield.destroy
  end

  protected

  def discard_blank_email
    self[:email] = nil
  end

  def set_password
    secure_string = SecureRandom.base64(User::PASSWORD_LENGTH)
    @password_policy = self.agent? ? account.agent_password_policy : account.contact_password_policy
    simple_password = @password_policy.nil? || @password_policy.new_record?
    secure_string = simple_password ? SecureRandom.base64(User::PASSWORD_LENGTH): @password_policy.generate_password
    self.password = secure_string
    self.password_confirmation = secure_string
    self.validate_password_format
  end

  def set_default_company
    if self.user_companies.present?
      default_company_count = self.user_companies.select(&:default).count
      if default_company_count != 1
        self.user_companies.each{ |uc| uc.default = false } if default_company_count > 1
        self.user_companies.first.default = true
      end
      default_user_company = self.user_companies.find { |uc| uc.default }
      self.user_companies = [default_user_company] unless has_multiple_companies_feature?
    end
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
    # @model_changes.symbolize_keys!
  end

  def set_company_name
    if (!self.company_name.present? && self.email)      
      email_domain =  self.email.split("@")[1]
      comp_id = Account.current.company_domains.find_by_domain(email_domain).try(:company_id)
      unless comp_id.nil?
        self.company_id = comp_id 
        self.customer_id = comp_id
      end
    end
  end

  def decode_name
    self.name = Mail::Encodings.unquote_and_convert_to(self.name, "UTF-8") \
      if ["=?UTF-8?B", "=?UTF-8?Q"].any? { |n| self.name.upcase.include?(n) }
  rescue Exception => e
    Rails.logger.debug "Exception while decoding contact name : #{self.name}, 
                        Account ID : #{self.account_id},
                        Error : #{e.message} #{e.backtrace}".squish
  end

  def delete_freshfone_user
    freshfone_user.destroy if freshfone_user
  end

  def delete_user_authorizations
    self.authorizations.destroy_all if self.authorizations
  end
  
  def delete_forum_moderator
    forum_moderator.destroy if forum_moderator
  end

  def clear_agent_caches
    clear_agent_list_cache 
    clear_agent_name_cache if @model_changes.key?(:name)
  end

  private

  def no_password?
    !password and !crypted_password
  end

  def validate_time_zone time_zone
    !(ActiveSupport::TimeZone.all.map(&:name).include? time_zone)
  end

  def validate_language language
    !(I18n.available_locales.include?(language.to_sym))
  end
  
  def sanitize_contact_name
    self.name.gsub!("\"", "") unless self.name.nil?
  end  

  def backup_customer_id
    unless self.changes.has_key?("perishable_token")
      if self.user_companies.length > 1 || has_multiple_companies_feature?
        user_comp = self.user_companies.find{ |uc| uc.default }
        self.customer_id = user_comp.present? ? user_comp.company_id : nil
        self.customer_id = nil if self.default_user_company.present? && self.default_user_company.marked_for_destruction?
      elsif self.default_user_company.present?
        self.customer_id = !self.default_user_company.marked_for_destruction? ? self.default_user_company.company_id : nil
      end
    end
  end

  def remove_white_space
    self.name.squish! unless self.name.nil?
  end

  def send_alert_email
    if self.agent?
      changed_attributes_names = ["primary email "]
      subject = "System notification: Agent email address changed"
      SecurityEmailNotification.send_later(:deliver_agent_email_change, self, self.email_was,subject,
        changed_attributes_names,User.current,"agent_email_change")
      if User.current.email !=self.email_was
          SecurityEmailNotification.send_later(:deliver_agent_email_change, self,User.current.email ,subject,
          changed_attributes_names,User.current,"admin_alert_email_change")
      end
    end
  end
end
