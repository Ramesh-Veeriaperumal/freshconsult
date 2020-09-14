class AccountAdditionalSettings < ActiveRecord::Base

  self.table_name =  "account_additional_settings"
  self.primary_key = :id

  include AccountAdditionalSettings::AdditionalSettings
  include AccountConstants
  include SandboxConstants
  include CentralLib::Util
  include Redis::OthersRedis
  include Redis::Keys::Others

  belongs_to :account
  serialize :supported_languages, Array
  serialize :secret_keys, Hash
  validates_length_of :email_cmds_delimeter, :minimum => 3, :message => I18n.t('email_command_delimeter_length_error_msg')
  after_update :handle_email_notification_outdate, :if => :had_supported_languages?
  after_initialize :set_default_rlimit, :backup_change, :load_state
  before_create :set_onboarding_version, :enable_freshdesk_freshsales_bundle
  after_commit :clear_cache
  after_commit :update_help_widget_languages, if: -> { Account.current.help_widget_enabled? && @portal_languages_changed }
  serialize :additional_settings, Hash
  serialize :resource_rlimit_conf, Hash
  validate :validate_bcc_emails
  validate :validate_supported_languages
  validate :validate_portal_languages, :if => :multilingual?

  after_commit :publish_account_central_payload, :backup_change
  after_commit :invoke_touchstone_account_worker, if: -> { omni_bundle_plan_enabled? && bundle_id_changed? }

  def toggle_skip_mandatory_option(boolean_value)
    additional_settings[:skip_mandatory_checks] = boolean_value
    save!
  end

  def save_field_service_management_settings(params)
    fsm_settings_default_value_hash = Admin::AdvancedTicketing::FieldServiceManagement::Constant::FSM_SETTINGS_DEFAULT_VALUES
    additional_settings[:field_service] = additional_settings.delete(:field_service_management) if additional_settings[:field_service_management]
    fsm_additional_settings = additional_settings[:field_service] || {}
    params.each do |key, value|
      if fsm_settings_default_value_hash[key.to_sym] == value
        fsm_additional_settings.delete(key.to_sym) if fsm_additional_settings
      else
        fsm_additional_settings[key.to_sym] = value
      end
    end
    additional_settings[:field_service] = fsm_additional_settings
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

  def portal_languages
    additional_settings[:portal_languages]
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
    @portal_languages_was = [] if @portal_languages_was.blank?
    @portal_languages_changed = (@portal_languages_was - portal_languages | portal_languages - @portal_languages_was).present? ? true : false
    additional_settings[:portal_languages] = portal_languages
  end

  def supported_language_setter(support_languages)
    @supported_languages_changed = true
    self.supported_languages = support_languages
  end

  def bundle_details_setter(bundle_id, bundle_name, new_signup = false)
    if bundle_id.present? && bundle_name.present?
      additional_settings[:bundle_id] = bundle_id
      additional_settings[:bundle_name] = bundle_name
      account.launch :omni_bundle_2020 if account.freshid_org_v2_enabled?
      launch_other_dependent_omni_features(new_signup) if account.omni_bundle_2020_enabled?
    end
  end

  def referring_product_setter(referring_product)
    additional_settings[:onboarding_version] = SubscriptionConstants::FDFSONBOARDING if referring_product.downcase == SubscriptionConstants::FRESHSALES
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

  def max_skills_per_account
    additional_settings.present? ? (additional_settings[:max_skills_limit] || DEFAULT_SKILL_LIMIT) : DEFAULT_SKILL_LIMIT
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

  def ocr_account_id
    additional_settings.try(:[], :ocr_account_id)
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

  def feedback_widget_captcha_allowed?
    !additional_settings[:feedback_widget].try(:[], 'disable_captcha')
  end

  def add_feedback_widget_settings(feedback_widget_hash)
    return if self.additional_settings[:feedback_widget] == feedback_widget_hash

    self.additional_settings ||= {}
    (self.additional_settings[:feedback_widget] ||= {}).merge!(feedback_widget_hash)
    save!
  end

  def update_onboarding_goals(goals)
    current_user = User.current
    additional_settings[:onboarding_goals] = goals
    save!
    Subscriptions::UpdateLeadToFreshmarketer.perform_async(event: ThirdCRM::EVENTS[:onboarding_goals], email: current_user.email, name: current_user.name)
  end

  def enable_freshdesk_freshsales_bundle
    metric = Account.current.conversion_metric
    freshdesk_brand_websites = GrowthHackConfig[:freshdesk_brand_websites]
    if metric.present? && metric.language == 'en' && ((metric.current_session_url == GrowthHackConfig[:freshdesk_signup] && freshdesk_brand_websites.include?(metric.referrer) || metric.referrer.blank?) || freshdesk_brand_websites.include?(metric.current_session_url))
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

  def create_freshid_migration(key)
    self.additional_settings ||= {}
    additional_settings[key] = true
    save
  end

  def destroy_freshid_migration(key)
    return if additional_settings.nil?

    additional_settings.delete(key)
    save
  end

  def freshid_migration_running?(key)
    return false if additional_settings.blank?

    additional_settings.fetch(key, false)
  end

  def agent_assist_config
    additional_settings[:agent_assist_config]
  end

  def update_agent_assist_config!(args)
    additional_settings[:agent_assist_config] ||= {}
    additional_settings[:agent_assist_config][:domain] = args[:domain] if args.key?(:domain)
    additional_settings[:agent_assist_config][:email_sent] = args[:email_sent] if args.key?(:email_sent)
    save!
  end

  def enable_freshid_custom_policy(config = {})
    additional_settings[:freshid_custom_policy_configs] ||= {}
    additional_settings[:freshid_custom_policy_configs][:agent] = config[:agent] if config.key?(:agent)
    additional_settings[:freshid_custom_policy_configs][:contact] = config[:contact] if config.key?(:contact)
    save!
  end

  def disable_freshid_custom_policy(key)
    if [:agent, :contact].include?(key)
      Account.current.safe_send("disable_#{key.downcase}_custom_sso!")
      additional_settings[:freshid_custom_policy_configs].try(:delete, key)
    end
    additional_settings.delete(:freshid_custom_policy_configs) if additional_settings[:freshid_custom_policy_configs].try(:empty?)
    save!
  end

  private

  def update_help_widget_languages
    Account.current.help_widgets.active.map(&:upload_configs)
  end

  def publish_account_central_payload
    model_changes = construct_model_changes
    if model_changes.present?
      account.model_changes = model_changes
      account.manual_publish_to_central(nil, :update, nil, false)
    end
  end

  def construct_model_changes
    changes = {}
    changes[:portal_languages] = [@portal_languages_was, portal_languages] if @portal_languages_changed
    if @supported_languages_changed
      primary_language = [Account.current.language]
      changes[:all_languages] = [@prev_supported_languages + primary_language, supported_languages + primary_language]
    end
    if Account.current.agent_collision_revamp_enabled?
      rts_changes = attribute_changes('additional_settings')
      rts_changes.merge!(attribute_changes('secret_keys'))
      rts_changes = rts_changes.slice(:rts_account_id, :rts_account_secret)
      changes.merge!(rts_changes)
    end
    changes
  end

  def omni_bundle_plan_enabled?
    current_account = Account.current
    current_account.try(:invoke_touchstone_enabled?) && current_account.try(:omni_bundle_2020_enabled?) && SubscriptionPlan.omni_channel_plan.map(&:id).include?(current_account.try(:subscription).try(:subscription_plan).try(:id))
  end

  def invoke_touchstone_account_worker
    # if the bundle_id is set for first time, the action would be create else would be an update call.
    if @bundle_id_was.nil?
      OmniChannelDashboard::AccountWorker.perform_async(action: 'create')
    else
      OmniChannelDashboard::AccountWorker.perform_async(action: 'update')
    end
  end

  def clear_cache
    self.account.clear_account_additional_settings_from_cache
    self.account.clear_api_limit_cache
  end

  def set_default_rlimit
    self.resource_rlimit_conf = self.resource_rlimit_conf.presence || DEFAULT_RLIMIT
  end

  def load_state
    @portal_languages_was = portal_languages
    @prev_supported_languages = supported_languages
    @bundle_id_was = additional_settings.try(:[], :bundle_id)
  end

  def bundle_id_changed?
    (additional_settings.try(:[], :bundle_id) != @bundle_id_was)
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

  def backup_change
    @old_model = attributes.deep_dup
  end

  def launch_other_dependent_omni_features(new_signup)
    account.launch :omni_agent_availability_dashboard if redis_key_exists?(OMNI_AGENT_AVAILABILITY_DASHBOARD)
    launch_conditional_omni_signup_features if new_signup
  end

  def launch_conditional_omni_signup_features
    condition_based_launchparty_features = get_others_redis_hash(CONDITION_BASED_OMNI_LAUNCHPARTY_FEATURES)
    if condition_based_launchparty_features.present?
      condition_based_launchparty_features.each { |key, value| account.launch(key.to_sym) if value.to_bool }
    end
  end
end
