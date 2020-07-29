class User < ActiveRecord::Base

  def freshid_user_class
    Account.current.freshid_org_v2_enabled? ? Freshid::V2::Models::User : Freshid::User
  end

  def create_freshid_user
    return if account.suppress_freshid_calls || freshid_disabled_or_customer? || (freshid_authorization.present? && authorizations.exists?(freshid_authorization.id))

    self.name = name_from_email if !self.name.present?
    Rails.logger.info "FRESHID Creating user :: a=#{self.account_id}, u=#{self.id}, email=#{self.email}"
    freshid_user = freshid_user_class.create(freshid_attributes)
    raise ActiveRecord::Rollback, "FRESHID REQUEST FAILED" unless freshid_user.present?
    sync_profile_from_freshid(freshid_user)
  end

  def create_freshid_user!
    return if freshid_disabled_or_customer? || (freshid_authorization.present? && authorizations.exists?(freshid_authorization.id))
    create_freshid_user
    save!
    enqueue_activation_email unless Account.current.try(:sandbox?)
  end

  def destroy_freshid_user
    if freshid_integration_enabled_account? && email_allowed_in_freshid? && freshid_authorization.present?
      remove_freshid_user
      freshid_authorization.destroy
      self.password_salt = self.crypted_password = nil
    end
  end

  def sync_profile_from_freshid(freshid_user)
    return if freshid_user.nil?
    freshid_user_id = Account.current.freshid_org_v2_enabled? ? freshid_user.id : freshid_user.uuid
    self.freshid_authorization = self.authorizations.build(
      provider: Freshid::Constants::FRESHID_PROVIDER,
      uid: freshid_user_id
    )
    assign_freshid_attributes_to_agent(freshid_user)
    Rails.logger.info "FRESHID User created :: a=#{self.account_id}, u=#{self.id}, email=#{self.email}, uuid=#{self.freshid_authorization.uid}"
  end

  def sync_profile_info_in_freshid
    return if freshid_authorization.nil?

    user_params = freshid_attributes.except(:domain, :email)
    freshid_user = account.freshid_org_v2_enabled? ? Freshid::V2::Models::User.new(id: freshid_authorization.uid) : Freshid::User.new(uuid: freshid_authorization.uid)
    freshid_user.update(user_params)
  end

  def update_freshid_user
    unless account.suppress_freshid_calls
      destroy_freshid_user # Delete old email user from freshID
      create_freshid_user # Create new email user in freshID
    end
  end

  def send_activation_mail_on_create
    enqueue_activation_email if @all_changes.nil? && !Thread.current[:create_sandbox_account] # new record saved successfully
  end

  def notify_uuid_change_to_user!
    enqueue_activation_email unless active?
  end

  def remove_freshid_user
    success = freshid_user_class.new({ id:freshid_authorization.uid, uuid: freshid_authorization.uid, domain: account.full_domain}).destroy
    raise ActiveRecord::Rollback, "FRESHID REQUEST FAILED" unless success
  end

  def valid_freshid_password?(incoming_password)
    password_available = password_flag_exists?(email) || false
    valid = password_available && valid_password?(incoming_password)
    ApiAuthLogger.log "FRESHID API auth Before FRESHID login a=#{account_id}, u=#{id}, password_available=#{password_available}, valid=#{valid}"
    unless valid
      remove_password_flag(email, account_id)
      valid = valid_freshid_login?(incoming_password)
      ApiAuthLogger.log "FRESHID API auth After FRESHID login a=#{account_id}, u=#{id}, valid=#{valid}"
      update_with_fid_password(incoming_password) if valid
    end
    valid
  end

  def reset_tokens!
    reset_persistence_token!
    reset_perishable_token!
    remove_password_flag(email, account_id)
  end

  def assign_freshid_attributes_to_contact freshid_user_data
    custom_user_info = freshid_user_data[:custom_user_info] || {}
    self.name = "#{freshid_user_data[:first_name]} #{freshid_user_data[:last_name]}".strip if freshid_user_data.key?(:first_name) || freshid_user_data.key?(:last_name)
    self.phone = freshid_user_data[:phone] if freshid_user_data.key?(:phone)
    self.mobile = freshid_user_data[:mobile] if freshid_user_data.key?(:mobile)
    self.job_title = freshid_user_data[:job_title] if freshid_user_data.key?(:job_title)
    self.assign_company(company) if freshid_user_data.key?(:company)
    self.assign_external_id(custom_user_info[:external_id]) if custom_user_info.key?(:external_id)
    self.active = true
  end

  def freshid_attributes
    freshid_first_name, freshid_middle_name, freshid_last_name = freshid_split_names
    { 
      first_name: freshid_first_name.presence,
      middle_name: freshid_middle_name.presence,
      last_name: freshid_last_name.presence,
      email: email,
      phone: phone.presence,
      mobile: mobile.presence,
      job_title: job_title.presence,
      domain: account.full_domain,
      company_name: account.account_configuration.admin_company_name
    }
  end

  def freshid_profile_info_updated?
    [:name, :phone, :mobile, :job_title].any? { |k| @all_changes.key?(k) }
  end

  def active_freshid_agent?
    active_and_verified? && freshid_enabled_and_agent?
  end

  def cache_freshid_user_tokens(type, token, key_expiry_time = nil)
    key = (type == :access_token ? FRESHID_ORG_V2_USER_ACCESS_TOKEN : FRESHID_ORG_V2_USER_REFRESH_TOKEN) % { account_id: account_id, user_id: id }
    key_expiry_time = nil if (type == :refresh_token)
    set_others_redis_key(key, token, key_expiry_time)
  end

  def get_freshid_user_tokens_from_cache(type = :access_token)
    key = (type == :access_token ? FRESHID_ORG_V2_USER_ACCESS_TOKEN : FRESHID_ORG_V2_USER_REFRESH_TOKEN) % { account_id: account_id, user_id: id }
    get_others_redis_key(key)
  end

  def freshid_enabled_and_agent?
    agent? && freshid_integration_enabled_account? && email_allowed_in_freshid?
  end

  def allow_agent_update?
    Account.current.allow_update_agent_enabled?
  end

  class << self

    def freshid_company_field_update_required?
      false
    end

  end

  private

    def freshid_integration_enabled_account?
      account.freshid_integration_enabled?
    end

    def freshid_disabled_or_customer?
      !freshid_enabled_and_agent?
    end

    def freshid_agent_not_signup_in_progress?
      freshid_enabled_and_agent? && !account.signup_in_progress?
    end

    def email_allowed_in_freshid?
      !FRESHID_IGNORED_EMAIL_IDS.include?(self.email)
    end

    def valid_freshid_login?(incoming_password)
      login_credentials = { 
        email: email, 
        password: incoming_password 
      }
      freshid_login = account.freshid_org_v2_enabled? ? Freshid::V2::Login.new(login_credentials) : Freshid::Login.new(login_credentials)
      freshid_login.authenticate_user
      freshid_login.valid_credentials?
    end

    def update_with_fid_password(fid_password)
      self.password = fid_password
      User.where(id: id).update_all(crypted_password: self.crypted_password, password_salt: self.password_salt)
      self.reload
      set_password_flag(email)
    end

    def assign_freshid_attributes_to_agent freshid_user
      self.name = freshid_full_name(freshid_user)
      self.phone = freshid_user.phone
      self.mobile = freshid_user.mobile
      self.job_title = freshid_user.job_title
      self.active = self.primary_email.verified = freshid_user.active?
      self.account.verify_account_with_email if freshid_user.active?
      self.password_salt = self.crypted_password = nil
    end

    def freshid_full_name(freshid_user)
      freshid_user.full_name || [freshid_user.first_name, freshid_user.middle_name, freshid_user.last_name].compact.join(' ').strip
    end

    def freshid_split_names
      name_splits = self.name.split(" ")
      [name_splits.first, name_splits[1..-2].join(" "), name_splits[1..-1].last]
    end
end