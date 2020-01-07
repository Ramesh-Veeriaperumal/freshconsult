class AccountAdditionalSettings < ActiveRecord::Base

  self.table_name =  "account_additional_settings"
  self.primary_key = :id

  include AccountAdditionalSettings::AdditionalSettings
  include AccountConstants
  include SandboxConstants

  belongs_to :account
  serialize :supported_languages, Array
  serialize :secret_keys, Hash
  validates_length_of :email_cmds_delimeter, :minimum => 3, :message => I18n.t('email_command_delimeter_length_error_msg')
  after_update :handle_email_notification_outdate, :if => :had_supported_languages?
  after_initialize :set_default_rlimit
  before_create :set_onboarding_version, :enable_freshdesk_freshsales_bundle
  after_commit :clear_cache
  after_commit :update_help_widget_languages, if: -> { Account.current.help_widget_enabled? && @portal_languages_changed }
  serialize :additional_settings, Hash
  serialize :resource_rlimit_conf, Hash
  validate :validate_bcc_emails
  validate :validate_supported_languages
  validate :validate_portal_languages, :if => :multilingual?

  def toggle_skip_mandatory_option(boolean_value)
    additional_settings[:skip_mandatory_checks] = boolean_value
    save!
  end

  def enable_skip_mandatory
    toggle_skip_mandatory_option(true) unless additional_settings[:skip_mandatory_checks]
  end

  def disable_skip_mandatory
    toggle_skip_mandatory_option(false) if additional_settings[:skip_mandatory_checks]
  end

  def handle_email_notification_outdate
    if supported_languages_changed?
    	removed = supported_languages_was - supported_languages
    	added = supported_languages - supported_languages_was

    	removed.each do |l|
    		DynamicNotificationTemplate.deactivate!(l)
    	end

    	added.each do |l|
    		DynamicNotificationTemplate.activate!(l)
    	end
    end
  end

  def had_supported_languages?
    !supported_languages_was.nil?
  end

  def notes_order=(val)
    additional_settings[:old_notes_first] = (val.to_s.to_bool rescue true)
  end

  def old_notes_first?
    if additional_settings[:old_notes_first].to_s.blank?
      true # default order, old notes appear first
    else
      additional_settings[:old_notes_first]
    end
  end

  def validate_bcc_emails
    (bcc_email || "").split(",").each do |email|
      errors.add(:base,"Invalid email: #{email}") unless email =~ AccountConstants::EMAIL_SCANNER
    end
  end

  def archive_days
    additional_settings[:archive_days] unless additional_settings.blank?
  end

  def custom_dashboard_limits
    if additional_settings.present? && additional_settings[:dashboard_limits].present?
      additional_settings[:dashboard_limits]
    elsif Account.current.field_service_management_enabled?
      dashboard_limits = DASHBOARD_LIMITS[:min].clone
      dashboard_limits[:dashboard] += 1
      dashboard_limits
    else
      DASHBOARD_LIMITS[:min]
    end
  end

  def portal_language_setter(portal_languages)
    @portal_languages_changed = true
    additional_settings[:portal_languages] = portal_languages
  end

  def delete_spam_tickets_days
    additional_settings[:delete_spam_days] unless additional_settings.blank?
  end

  def is_trial_extension_requested?
    additional_settings.blank? ? false : additional_settings[:trial_extension_requested] == true
  end

  def max_template_limit
    additional_settings[:max_template_limit] unless additional_settings.blank?
  end

  def freshmarketer_linked?
    freshmarketer_hash.present? && freshmarketer_hash[:acc_id].present?
  end

  def frustration_tracking_fm_linked?
    freshmarketer_hash.present? && additional_settings[:widget_predictive_support].present?
  end

  [:acc_id, :auth_token, :cdn_script, :app_url, :integrate_url].each do |item|
    define_method "freshmarketer_#{item}" do
      freshmarketer_hash[item] if freshmarketer_hash.present?
    end
  end

  def ticket_exports_limit
    additional_settings[:ticket_export_per_user_limit] unless additional_settings.blank?
  end

  def archive_ticket_exports_limit
    additional_settings[:archive_ticket_export_per_account_limit] unless additional_settings.blank?
  end

  def contact_exports_limit
    additional_settings[:contact_export_per_account_limit] if additional_settings.present?
  end

  def company_exports_limit
    additional_settings[:company_export_per_account_limit] if additional_settings.present?
  end

  def create_clone_job(destination_id, email = User.current.email, state = :clone_initiated)
    raise StandardError unless STATUS_KEYS_BY_TOKEN.key?(state)
    clone_details = {
      status: STATUS_KEYS_BY_TOKEN[state],
      clone_account_id: destination_id,
      initiated_by: email,
      last_error: "",
      additional_data: ""
    }
    self.additional_settings ||= {}
    additional_settings[:clone] = clone_details
    save
  end

  def update_last_error(e, state)
    raise StandardError unless STATUS_KEYS_BY_TOKEN.key?(state)
    clone_details = {
      status: STATUS_KEYS_BY_TOKEN[state],
      last_error: e.to_s
    }
    additional_settings[:clone] = (additional_settings[:clone] || {}).merge(clone_details)
    save
  end

  def mark_as!(state)
    update_last_error(nil, state)
  end

  def clone_status
    return nil unless additional_settings.present?
    status_id = additional_settings.fetch(:clone, {}).fetch(:status, nil)
    return nil unless PROGRESS_KEYS_BY_TOKEN.key?(status_id)
    PROGRESS_KEYS_BY_TOKEN[status_id]
  end

  def destroy_clone_job
    additional_settings.delete(:clone)
    save
  end

  def reset_ocr_account_id
    additional_settings.delete(:ocr_account_id)
  end

  def freshmarketer_settings_hash
    app_url = freshmarketer_app_url.split('//').last
    {
      org_id: app_url.split('/org/').last.split('/').first.to_i,
      project_id: app_url.split('/project/').last.split('/').first.to_i,
      cdn_script: freshmarketer_cdn_script
    }
  end

  def freshmarketer_name
    freshmarketer_app_url.split('//').last.split('/').first
  end

  def widget_predictive_support_hash
    additional_settings[:widget_predictive_support] || {}
  end

  def increment_dashboard_limit
    return if self.additional_settings[:dashboard_limits].nil?
    self.additional_settings[:dashboard_limits][:dashboard] += 1
    self.save
  end

  def decrement_dashboard_limit
    return if self.additional_settings[:dashboard_limits].nil?
    self.additional_settings[:dashboard_limits][:dashboard] -= 1
    self.save
  end

  def widget_count
    key = Account.current.subscription.sprout_plan? ? :sprout : :non_sprout
    additional_settings[:widget_count] || AccountConstants::WIDGET_COUNT_FOR_PLAN[key]
  end

  def update_onboarding_goals(goals)
    additional_settings[:onboarding_goals] = goals
    save!
  end

  def enable_freshdesk_freshsales_bundle
    metric = Account.current.conversion_metric
    freshdesk_brand_websites = GrowthHackConfig[:freshdesk_brand_websites]
    if Account.current.launched?(:freshdesk_freshsales_bundle) && metric.present? && metric.language == 'en' && ((metric.current_session_url == GrowthHackConfig[:freshdesk_signup] && freshdesk_brand_websites.include?(metric.referrer) || metric.referrer.blank?) || freshdesk_brand_websites.include?(metric.current_session_url))
      self.additional_settings ||= {}
      self.additional_settings[:freshdesk_freshsales_bundle] = true
    end
  end

  def regenerate_help_widget_secret
    self.secret_keys = {} if secret_keys.nil?
    self.secret_keys[:help_widget] = SecureRandom.hex
    self.save
  end

  def help_widget_secret
    secret_keys[:help_widget]
  end

  def rts_account_id
    additional_settings[:rts_account_id]
  end

  def rts_account_secret
    EncryptorDecryptor.new(RTSConfig['db_cipher_key']).decrypt(secret_keys[:rts_account_secret]) if secret_keys[:rts_account_secret].present?
  end

  def assign_rts_account_secret(value)
    secret_keys[:rts_account_secret] = EncryptorDecryptor.new(RTSConfig['db_cipher_key']).encrypt(value)
  end

  private

  def update_help_widget_languages
    Account.current.help_widgets.active.map(&:upload_configs)
    @portal_languages_changed = false
  end

  def clear_cache
    self.account.clear_account_additional_settings_from_cache
    self.account.clear_api_limit_cache
  end

  def set_default_rlimit
    self.resource_rlimit_conf = self.resource_rlimit_conf.presence || DEFAULT_RLIMIT
  end

  def validate_supported_languages
    if ((self.supported_languages || []) - Language.all_codes).present?
      errors.add(:supported_languages, I18n.t('accounts.multilingual_support.supported_languages_validity'))
      return false
    end
    return true
  end

  def multilingual?
    Account.current.multilingual?
  end

  def validate_portal_languages
    if ((self.additional_settings[:portal_languages] || []) - (self.supported_languages || [])).present?
      errors.add(:portal_languages, I18n.t('accounts.multilingual_support.portal_languages_validity'))
      return false
    end
    return true
  end

  def freshmarketer_hash
    additional_settings[:freshmarketer] || {}
  end
end
