class Account < ActiveRecord::Base

  LP_FEATURES = [
    :select_all, :round_robin_capping, :suggest_tickets,
    :customer_sentiment_ui, :dkim, :scheduled_ticket_export,
    :ticket_contact_export, :email_failures, :disable_emails,
    :falcon_portal_theme, :freshid, :freshchat_integration,
    :facebook_page_redirect, :announcements_tab, :shopify_actions,
    :ticket_central_publish, :company_central_publish, :solutions_central_publish,
    :launch_smart_filter, :outgoing_attachment_limit_25, :incoming_attachment_limit_25,
    :whitelist_sso_login, :apigee, :admin_only_mint, :customer_notes_s3,
    :imap_error_status_check, :va_any_field_without_none, :api_es,
    :encode_emoji, :auto_complete_off, :sandbox_lp, :note_central_publish,
    :dependent_field_validation, :post_central_publish, :encode_emoji_subject,
    :time_sheets_central_publish, :twitter_common_redirect,
    :euc_migrated_twitter, :new_ticket_recieved_metric, :ner,
    :dashboard_announcement_central_publish, :timeline, :disable_banners,
    :twitter_handle_publisher, :count_service_es_writes, :count_service_es_reads,
    :sso_login_expiry_limitation, :db_to_bitmap_features_migration_phase2,
    :undo_send, :old_link_back_url_validation, :stop_contacts_count_query,
    :db_to_bitmap_features_migration, :denormalized_select_for_update,
    :trial_subscription, :installed_app_publish, :es_tickets,
    :twitter_dm_outgoing_attachment, :twitter_mention_outgoing_attachment,
    :whitelist_supervisor_sla_limitation, :es_msearch, :year_in_review_2017, :year_in_review_2018,
    :new_onboarding, :onboarding_inlinemanual, :skip_portal_cname_chk,
    :product_central_publish, :help_widget, :redis_picklist_id,
    :bot_email_channel, :bot_email_central_publish, :description_by_request,
    :bot_chat_history, :new_es_api, :filter_factory, :ticket_fields_central_publish,
    :shopify_actions, :skip_invoice_due_warning, :automation_revamp,
    :scheduled_export_fix, :compact_lang_detection,
    :facebook_page_scope_migration, :agent_group_central_publish, :custom_fields_search,
    :update_billing_info, :allow_billing_info_update
  ].freeze

  DB_FEATURES = [
    :custom_survey, :requester_widget, :archive_tickets, :sitemap, :freshfone
  ].freeze

  BITMAP_FEATURES = [
    :split_tickets, :add_watcher, :traffic_cop, :custom_ticket_views, :supervisor,
    :create_observer, :sla_management, :email_commands, :assume_identity, :rebranding,
    :custom_apps, :custom_ticket_fields, :custom_company_fields, :custom_contact_fields,
    :occasional_agent, :allow_auto_suggest_solutions, :basic_twitter, :basic_facebook,
    :multi_product, :multiple_business_hours, :multi_timezone, :customer_slas,
    :layout_customization, :advanced_reporting, :timesheets, :multiple_emails,
    :custom_domain, :gamification, :gamification_enable, :auto_refresh, :branding,
    :advanced_dkim, :basic_dkim, :system_observer_events, :unique_contact_identifier,
    :ticket_activity_export, :caching, :private_inline, :collaboration, :hipaa,
    :multi_dynamic_sections, :skill_based_round_robin, :auto_ticket_export,
    :user_notifications, :falcon, :multiple_companies_toggle, :multiple_user_companies,
    :denormalized_flexifields, :custom_dashboard, :support_bot, :image_annotation,
    :tam_default_fields, :todos_reminder_scheduler, :smart_filter, :ticket_summary,
    :opt_out_analytics, :freshchat, :disable_old_ui, :contact_company_notes,
    :sandbox, :oauth2, :session_replay, :segments, :freshconnect, :proactive_outreach,
    :audit_logs_central_publish, :audit_log_ui, :omni_channel_routing, :undo_send,
    :custom_encrypted_fields, :freshid_saml, :custom_translations, :parent_child_infra, :canned_forms
  ].concat(ADVANCED_FEATURES + ADVANCED_FEATURES_TOGGLE)

  COMBINED_VERSION_ENTITY_KEYS = [
    Helpdesk::TicketField::VERSION_MEMBER_KEY,
    ContactField::VERSION_MEMBER_KEY,
    CompanyField::VERSION_MEMBER_KEY,
    CustomSurvey::Survey::VERSION_MEMBER_KEY,
    Freshchat::Account::VERSION_MEMBER_KEY,
    AgentGroup::VERSION_MEMBER_KEY
  ]

  PODS_FOR_BOT = ['poduseast1'].freeze

  LP_FEATURES.each do |item|
    define_method "#{item.to_s}_enabled?" do
      launched?(item)
    end
  end

  DB_FEATURES.each do |item|
    define_method "#{item.to_s}_enabled?" do
      features?(item)
    end
  end

  BITMAP_FEATURES.each do |item|
    define_method "#{item.to_s}_enabled?" do
      has_feature?(item)
    end
  end

  Collaboration::Ticket::SUB_FEATURES.each do |item|
    define_method "#{item.to_s}_enabled?" do
      self.collaboration_enabled? && (self.collab_settings[item.to_s] == 1)
    end
  end

  Fdadmin::FeatureMethods::BITMAP_FEATURES_WITH_VALUES.each do |key, value|
    define_method "#{key.to_s}_feature_changed?" do
      self.changes[:plan_features].present? && bitmap_feature_changed?(value)
    end
  end

  def features?(*feature_names)
    feature_names = feature_names.to_set
    if launched? :db_to_bitmap_features_migration_phase2
      features_migrated_to_bmp = Account.handle_feature_name_change(feature_names &
        DB_TO_BITMAP_MIGRATION_P2_FEATURES_LIST)
      features_migrated_to_lp = feature_names & DB_TO_LP_MIGRATION_P2_FEATURES_LIST
      features_not_migrated = feature_names -
                              DB_TO_BITMAP_MIGRATION_P2_FEATURES_LIST -
                              DB_TO_LP_MIGRATION_P2_FEATURES_LIST
      Rails.logger.info("These features are not yet migrated: #{features_not_migrated.inspect}")
      has_features?(*features_migrated_to_bmp) &&
        launched?(*features_migrated_to_lp) &&
        super(*features_not_migrated)
    elsif launched? :db_to_bitmap_features_migration # phase 1
      features_migrated_to_bmp = Account.handle_feature_name_change(feature_names &
        DB_TO_BITMAP_MIGRATION_FEATURES_LIST)
      features_not_migrated = feature_names - DB_TO_BITMAP_MIGRATION_FEATURES_LIST
      has_features?(*features_migrated_to_bmp) &&
        super(*features_not_migrated)
    else
      super(*feature_names)
    end
  end

  def self.handle_feature_name_change(feature_names)
    FEATURE_NAME_CHANGES.each do |key, val|
      unless feature_names.delete?(key).nil?
        Rails.logger.info("Feature name changed from #{key} to #{val}")
        feature_names.add val
      end
    end
    feature_names
  end

  def has_both_feature? f
    features?(f) && launched?(f)
  end

  def restricted_helpdesk?
    features?(:restricted_helpdesk) && helpdesk_restriction_enabled?
  end

  def tag_based_article_search_enabled?
    ismember?(TAG_BASED_ARTICLE_SEARCH, self.id)
  end

  def classic_reports_enabled?
    ismember?(CLASSIC_REPORTS_ENABLED, self.id)
  end

  def old_reports_enabled?
    ismember?(OLD_REPORTS_ENABLED, self.id)
  end

  def plugs_enabled_in_new_ticket?
    ismember?(PLUGS_IN_NEW_TICKET,self.id)
  end

  def pass_through_enabled?
    pass_through_enabled
  end

  def any_survey_feature_enabled?
    survey_enabled? || default_survey_enabled? || custom_survey_enabled?
  end

  def any_survey_feature_enabled_and_active?
    new_survey_enabled? ? active_custom_survey_from_cache.present? :
      features?(:surveys, :survey_links)
  end

  def link_tkts_or_parent_child_enabled?
    link_tickets_enabled? || parent_child_infra_enabled?
  end

  def survey_enabled?
    features?(:surveys)
  end

  def new_survey_enabled?
    default_survey_enabled? || custom_survey_enabled?
  end

  def default_survey_enabled?
    features?(:default_survey) && !custom_survey_enabled?
  end

  def count_es_enabled?
    (launched?(:es_count_reads) || launched?(:list_page_new_cluster)) && features?(:countv2_reads)
  end

  def count_es_api_enabled?
    count_es_enabled? && api_es_enabled?
  end

  def count_es_tickets_enabled?
    count_es_enabled? && es_tickets_enabled?
  end

  def count_es_writes_enabled?
    features?(:countv2_writes) || launched?(:count_service_es_writes)
  end

  def customer_sentiment_enabled?
    Rails.logger.info "customer_sentiment : #{launched?(:customer_sentiment)}"
    launched?(:customer_sentiment)
  end

  def freshfone_enabled?
    features?(:freshfone) and freshfone_account.present?
  end

  def freshcaller_enabled?
    has_feature?(:freshcaller) and freshcaller_account.present?
  end

  def livechat_enabled?
    features?(:chat) and !chat_setting.site_id.blank?
  end

  def freshchat_routing_enabled?
    livechat_enabled? and features?(:chat_routing)
  end

  def supervisor_feature_launched?
    features?(:freshfone_call_monitoring) || features?(:agent_conference)
  end

  def compose_email_enabled?
    !features?(:compose_email) || ismember?(COMPOSE_EMAIL_ENABLED, self.id)
  end

  def helpdesk_restriction_enabled?
    features?(:helpdesk_restriction_toggle) || launched?(:restricted_helpdesk)
  end

  def dashboard_disabled?
    ismember?(DASHBOARD_DISABLED, self.id)
  end

  def dashboardv2_enabled?
    launched?(:admin_dashboard) || launched?(:supervisor_dashboard) || launched?(:agent_dashboard)
  end

  def restricted_compose_enabled?
    ismember?(RESTRICTED_COMPOSE, self.id)
  end

  def hide_agent_metrics_feature?
    features?(:euc_hide_agent_metrics)
  end

  def new_pricing_launched?
    on_new_plan? || redis_key_exists?(NEW_SIGNUP_ENABLED)
  end

  def advance_facebook_enabled?
    features?(:facebook)
  end

  def advanced_twitter?
    features? :twitter
  end

  def twitter_smart_filter_enabled?
    smart_filter_enabled? && launch_smart_filter_enabled?
  end

  def twitter_smart_filter_revoked?
    redis_key_exists?(TWITTER_SMART_FILTER_REVOKED) && smart_filter_enabled? && !Account.current.twitter_handles_from_cache.blank?
  end

  def on_new_plan?
    @on_new_plan ||= [:sprout_jan_17,:blossom_jan_17,:garden_jan_17,:estate_jan_17,:forest_jan_17].include?(plan_name)
  end

  def tags_filter_reporting_enabled?
    features?(:tags_filter_reporting)
  end

  def dashboard_new_alias?
    launched?(:dashboard_new_alias)
  end

  def tkt_templates_enabled?
    @templates ||= (features?(:ticket_templates) || parent_child_tickets_enabled?)
  end

  def auto_ticket_export_enabled?
    @auto_ticket_export ||= (launched?(:auto_ticket_export) || has_feature?(:auto_ticket_export))
  end

  def ticket_contact_export_enabled?
    @ticket_contact_export_enabled ||= (launched?(:ticket_contact_export) || auto_ticket_export_enabled?)
  end

  def selectable_features_list
    SELECTABLE_FEATURES_DATA || {}
  end

  def chat_activated?
    !subscription.suspended? && features?(:chat) && !!chat_setting.site_id
  end

  def collaboration_enabled?
    @collboration ||= has_feature?(:collaboration) && self.collab_settings.present?
  end

  def freshconnect_enabled?
    has_feature?(:freshconnect) && freshconnect_account.present? && freshconnect_account.enabled
  end

  def falcon_ui_enabled?(current_user = :no_user)
    valid_user = (current_user == :no_user ? true : (current_user && current_user.is_falcon_pref?))
    valid_user && (falcon_enabled? || check_admin_mint? || disable_old_ui_enabled?)
  end

  def check_admin_mint?
    return false if User.current.nil?
    admin_only_mint_enabled? && User.current.privilege?(:admin_tasks)
  end

  def falcon_support_portal_theme_enabled?
    falcon_ui_enabled? && falcon_portal_theme_enabled?
  end

  #this must be called instead of using launchparty in console or from freshops to set all necessary things needed
  def enable_falcon_ui
    set_falcon_redis_keys
    self.add_feature(:falcon)
  end

  def set_falcon_redis_keys
    hash_set = Hash[COMBINED_VERSION_ENTITY_KEYS.collect { |key| ["#{key}_LIST", Time.now.utc.to_i] }]
    set_others_redis_hash(version_key, hash_set)
  end

  def support_bot_configured?
    support_bot_enabled? && bot_onboarded?
  end

  def revoke_support_bot?
    redis_key_exists?(REVOKE_SUPPORT_BOT) || (Rails.env.production? && PODS_FOR_BOT.exclude?(PodConfig['CURRENT_POD']))
  end

  def help_widget_enabled?
    launched?(:help_widget)
  end

  def undo_send_enabled?
    has_feature?(:undo_send) || launched?(:undo_send)
  end

  # Checks if a bitmap feature has been added or removed
  # old_feature ^ new_feature - Will give the list of all features that have been modified in update call
  # (old_feature ^ new_feature) & (2**feature_val) - Will return zero if the given feature has not been modified
  # old_feature & (2**feature_val) - Checks if the given feature is part of old_feature. If so, the feature has been removed. Else,it's been added.
  def bitmap_feature_changed?(feature_val)
    old_feature = self.changes[:plan_features][0].to_i
    new_feature = self.changes[:plan_features][1].to_i
    return false if ((old_feature ^ new_feature) & (2**feature_val)).zero?
    @action = (old_feature & (2**feature_val)).zero? ? "add" : "drop"
  end

  def cascade_dispatcher_enabled?
    has_feature?(:cascade_dispatcher) || features?(:cascade_dispatchr)
  end

  def custom_translations_enabled?
    redis_picklist_id_enabled? && has_feature?(:custom_translations)
  end
end
