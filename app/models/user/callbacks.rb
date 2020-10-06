class User < ActiveRecord::Base

  before_validation :discard_blank_email, :unless => :email_available?
  before_validation :downcase_email, on: :create, if: :email_available?
  before_validation :set_password, :if => [:active?, :email_available?, :no_password?, :freshid_disabled_or_customer?]
  before_validation :remove_white_space
  
  before_create :set_company_name, :unless => :helpdesk_agent?
  before_create :decode_name
  before_create :populate_privileges, :if => :helpdesk_agent?
  before_create :create_freshid_user, if: :freshid_agent_not_signup_in_progress?
  before_create :update_agent_default_preferences, if: :agent?

  before_update :populate_privileges, :if => :roles_changed?
  before_update :destroy_user_roles, :delete_user_authorizations, :if => :deleted?

  before_update :backup_user_changes, :clear_redis_for_agent

  before_update :create_freshid_user, if: :converted_to_agent?
  before_update :update_agent_default_preferences, if: -> { converted_to_agent? && !was_agent? }
  before_update :update_freshid_user, if: [:freshid_enabled_and_agent?, :email_id_changed?]
  before_update :set_gdpr_preference, :if => [:privileges_changed?, :agent_to_admin?]
  before_update :remove_gdpr_preference, :if => [:privileges_changed?, :admin_to_agent?]

  after_update  :destroy_scheduled_ticket_exports, :if => :privileges_changed?
  after_update :set_user_companies_changes

  after_update :send_alert_email, if: [:email_id_changed?, :agent?, :non_anonymous_account?]
  before_save :set_time_zone, :set_default_company
  before_save :set_language, :unless => :detect_language?
  before_save :trigger_perishable_token_reset, if: :email_id_changed?
  before_save :sanitize_contact_name, :set_contact_name, :update_user_related_changes
  before_save :set_customer_privilege, :set_contractor_privilege, :if => :customer?
  before_save :restrict_domain, if: :email_id_changed?
  before_save :backup_customer_id
  before_save :persist_updated_at
  before_save :populate_or_update_twitter_requester_handle_id, on: %i[create update], if: :twitter_id_updated?


  publishable on: [:create, :update, :destroy], if: -> { !helpdesk_agent? || helpdesk_agent_changed? }

  before_destroy :save_deleted_user_info

  after_commit :destroy_freshid_user, on: :update, if: -> { converted_to_contact? }

  after_commit ->(obj) { obj.clear_agent_caches }, on: :create, if: :agent?
  after_commit ->(obj) { obj.clear_agent_caches }, on: :destroy, if: :agent?
  after_commit :update_agent_caches, on: :update

  after_commit :subscribe_event_create, on: :create, :if => :allow_api_webhook?

  after_commit :subscribe_event_update, on: :update, :if => :allow_api_webhook?
  
  after_commit :inst_app_business_event_create, on: :create, :if => :allow_inst_app_business_rule?
  
  #after_commit :discard_contact_field_data, on: :update, :if => [:helpdesk_agent_updated?, :agent?]
  after_commit :delete_forum_moderator, on: :update, :if => :helpdesk_agent_updated?
  after_commit :propagate_api_key_to_seeder_accounts, on: :update, if: :admin_api_key_updated?
  after_commit :deactivate_monitorship, on: :update, :if => :blocked_deleted?
  after_commit :sync_to_export_service, on: :update, :if => [:agent?, :time_zone_updated?]

  after_commit :send_activation_mail_on_create, on: :create, if: :freshid_agent_not_signup_in_progress?
  after_commit :enqueue_activation_email, on: :update, if: [:freshid_enabled_and_agent?, :converted_to_agent_or_email_updated?]
  after_commit :push_contact_deleted_info, on: :update, :if => :deleted?
  after_rollback :remove_freshid_user, on: :create, if: :freshid_enabled_and_agent?
  after_rollback :remove_freshid_user, on: :update, if: [:freshid_integration_enabled_account?, :converted_to_agent?]
  after_commit :tag_update_central_publish, :on => :update, :if => :tags_updated?
  after_commit :sync_profile_info_in_freshid, on: :update, if: [:freshid_enabled_and_agent?, :freshid_profile_info_updated?, :allow_agent_update?]

  # Callbacks will be executed in the order in which they have been included. 
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher
  include Aloha::Util

  def tag_update_central_publish
    CentralPublish::UpdateTag.perform_async(tag_update_model_changes)
  end

  def publish_agent_update_central_payload
    changes = model_changes.slice(:name, :email, :phone)
    agent.publish_update_central_payload(changes)
  end

  def populate_or_update_twitter_requester_handle_id
    return if ignore_populate_or_update?

    twitter_user_handle_id = fetch_twitter_user_handle_id
    self.twitter_requester_handle_id = twitter_user_handle_id || nil
  rescue StandardError => e
    Rails.logger.error "Error while populate or update twitter_requester_handle_id account_id: #{Account.current.id} user_id: #{id} error: #{e.message} #{e.backtrace[0..10]}"
  end

  def ignore_populate_or_update?
    transaction_include_action?(:create) && twitter_id && twitter_requester_handle_id
  end

  def twitter_id_updated?
    Account.current.twitter_api_compliance_enabled? && changes.include?('twitter_id')
  end

  def fetch_twitter_user_handle_id
    twitter_handle = Account.current.twitter_handles.active.last
    return nil unless twitter_handle && twitter_id

    twitter = TwitterWrapper.new(twitter_handle).get_twitter
    twitter.user(twitter_id).id.to_s
  rescue Twitter::Error => e
    Rails.logger.error "Twitter REST API Exception: #{Account.current.id} user_id: #{id} twitter_id: #{twitter_id} Twitter::Error: #{e.message}}"
    nil
  end

  def tag_update_model_changes
    @latest_tags = self.tags.pluck(:name)
    tag_args = {}
    tag_args[:added_tags] = @latest_tags - (@prev_tags || [])
    tag_args[:removed_tags] = (@prev_tags || []) - @latest_tags
    tag_args
  end
    
  def tags_updated?
    self.tags_updated
  end

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

  def update_agent_default_preferences
    new_pref = { focus_mode: true }
    self.merge_preferences = { agent_preferences: new_pref }
  end

  def persist_updated_at
    if (self.changes.keys.map(&:to_sym) & PROFILE_UPDATE_ATTRIBUTES).any? || 
      (self.flexifield.changes.keys & self.flexifield.ff_fields).any? || 
      self.tag_use_updated
        self.record_timestamps = true
    else
      self.record_timestamps = false
    end
    true
  end

  def set_gdpr_preference
    self.merge_preferences = { :agent_preferences => {
      :gdpr_acceptance => true,
      :gdpr_admin_id => User.current.id
    }}
  end

  def remove_gdpr_preference
    self.merge_preferences = { :agent_preferences => {
      :gdpr_acceptance => false,
    }}
  end

  def trigger_perishable_token_reset
    # separate query was being fired to update perishable_token
    # which inturn pushes 2 messages to central
    self.perishable_token = self.reset_perishable_token
    self.perishable_token_reset = true
  end

  def agent_to_admin?
     admin_privilege_updated?
  end

  def admin_to_agent?
     admin_privilege_updated? true
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
    self.language = account.language if language.nil? ||
                                        validate_language(language) ||
                                        !Account.current.has_feature?(:multi_language)

  end

  def detect_language?
    self.created_from_email || self.detect_language
  end

  def discard_contact_field_data
    self.flexifield.destroy
  end

  def save_deleted_user_info
    @deleted_model_info = as_api_response(:central_publish)
  end

  def delete_user_authorizations
    authorizations.authorizations_without_freshid.destroy_all if authorizations.exists?
  end

  def non_anonymous_account?
    !account.anonymous_account?
  end

  protected

  def discard_blank_email
    self[:email] = nil
  end

  def downcase_email
    self[:email].downcase!
  end

# admin_flag is to know whether this method has been called in the context 
# of admin to agent or agent to admin check
  def admin_privilege_updated? admin_to_agent = false
    old_privilege = @all_changes[:privileges][0]
    new_privilege = @all_changes[:privileges][1]
    admin_privilege_mask = Role.privileges_mask(ADMIN_PRIVILEGES)
    was_admin = ( admin_privilege_mask & old_privilege.to_i > 0 )
    is_admin =  ( admin_privilege_mask & new_privilege.to_i > 0 )
    return false if was_admin == is_admin # no change in admin privileges 
    admin_to_agent ? was_admin : is_admin
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
      self.name = name_from_email
    end
  end

  def name_from_email
    (email_obtained.split("@")[0]).capitalize
  end

  def email_obtained
    self[:email]
  end

  def update_user_related_changes
    @model_changes = self.changes.clone
    if roles_changed?
      role_changes = { :added => @added_roles || [], 
                       :removed => @removed_roles || [] }
      @model_changes.merge!("roles" => role_changes)
    end
    @model_changes.merge!(flexifield.changes)
    # @model_changes.symbolize_keys!
  end

  def set_user_companies_changes
    @all_changes.merge!({ company_ids: company_ids }) if self.user_companies_updated && @all_changes
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
  
  def delete_forum_moderator
    forum_moderator.destroy if forum_moderator
  end

  def propagate_api_key_to_seeder_accounts
    current_account = Account.current
    send_updated_access_token_to_chat if current_account.freshchat_account_present?
    send_updated_access_token_to_caller if current_account.freshcaller_account_present?
  end

  def clear_agent_caches
    clear_agent_list_cache
    clear_agent_details_cache
    clear_agent_name_cache if @model_changes.key?(:name)
  end

  def push_contact_deleted_info
    if User.current
      # UserNotifier.send_later(:push_contact_deleted_info, self.account, self, User.current, Time.now )
    end
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
    name.gsub!(CONTACT_NAME_SANITIZER_REGEX, '') if name.present?
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
      @model_changes[:customer_id] = changes[:customer_id] if changes.key?(:customer_id)
      true
    end
  end

  def remove_white_space
    self.name.squish! unless self.name.nil?
  end

  def send_alert_email
    if agent?
      changed_attributes_names = ["primary email "]
      SecurityEmailNotification.send_later(:deliver_agent_email_change_alert, self, self.email_was,
        changed_attributes_names, User.current, "agent_email_change", { :locale_object => self })
      if User.current.email.present? && User.current.email != self.email_was
          SecurityEmailNotification.send_later(:deliver_agent_email_change_alert, self, User.current.email,
            changed_attributes_names, User.current, "admin_alert_email_change", { :locale_object => User.current })
      end
    end
  end

  def destroy_scheduled_ticket_exports
    if !(self.privilege?(:admin_tasks) && self.privilege?(:view_reports))
      Account.current.scheduled_ticket_exports_from_cache.each do |scheduled_ticket_export|
        scheduled_ticket_export.destroy if scheduled_ticket_export.user_id == self.id
      end 
    end
  end
end
