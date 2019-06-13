class Account < ActiveRecord::Base

  LP_FEATURES = [
    :select_all, :round_robin_capping, :suggest_tickets, :customer_sentiment_ui,
    :dkim, :scheduled_ticket_export, :ticket_contact_export, :disable_emails,
    :year_in_review_2017, :falcon_portal_theme, :freshid, :freshchat_integration,
    :announcements_tab, :sso_login_expiry_limitation, :es_msearch, :ticket_central_publish,
    :solutions_central_publish, :launch_smart_filter, :outgoing_attachment_limit_25,
    :whitelist_sso_login, :admin_only_mint, :customer_notes_s3, :undo_send,
    :imap_error_status_check, :va_any_field_without_none, :encode_emoji, :auto_complete_off,
    :csat_email_scan_compatibility, :dependent_field_validation, :post_central_publish,
    :encode_emoji_subject, :note_central_publish, :db_to_bitmap_features_migration_phase2,
    :time_sheets_central_publish, :incoming_attachment_limit_25, :fetch_ticket_from_ref_first,
    :allow_huge_ccs, :euc_migrated_twitter, :new_ticket_recieved_metric, :mint_portal_applicable,
    :twitter_microservice, :twitter_handle_publisher, :count_service_es_writes,
    :count_service_es_reads, :quoted_text_parsing_feature, :shopify_actions,
    :count_service_es_writes, :old_link_back_url_validation, :db_to_bitmap_features_migration,
    :installed_app_publish, :denormalized_select_for_update, :disable_banners,
    :skip_invoice_due_warning, :company_central_publish, :product_central_publish,
    :redis_picklist_id, :help_widget, :bot_email_channel, :bot_email_central_publish,
    :description_by_default, :ticket_fields_central_publish, :facebook_page_scope_migration,
    :agent_group_central_publish, :custom_fields_search,:update_billing_info, :fluffy,
    :allow_billing_info_update, :pricing_plan_change_2019, :tag_central_publish, :native_apps,
    :surveys_central_publish, :id_for_choices_write, :nested_field_revamp, :session_logs, :bypass_signup_captcha,
    :freshvisual_configs, :ticket_field_limit_increase, :join_ticket_field_data, :contact_company_split,
    :contact_field_central_publish, :company_field_central_publish, :simple_outreach, :disable_simple_outreach,
    :disable_field_service_management, :disable_mint_analytics, :freshid_org_v2, :hide_agent_login,
    :addon_based_billing, :kbase_mint, :text_custom_fields_in_etl, :email_spoof_check,
    :disable_email_spoof_check, :onboarding_i18n, :webhook_blacklist_ip, :recalculate_daypass, :sandbox_single_branch,
    :fb_page_api_improvement, :attachment_redirect_expiry, :solutions_agent_portal, :solutions_agent_metrics, :fuzzy_search,
    :delete_trash_daily, :ticket_type_filter_in_trends_widget
  ].freeze

  DB_FEATURES = [:custom_survey, :requester_widget, :archive_tickets, :sitemap, :freshfone].freeze

  BITMAP_FEATURES = [
    :split_tickets, :add_watcher, :traffic_cop, :custom_ticket_views, :supervisor,
    :create_observer, :sla_management, :email_commands, :assume_identity, :rebranding,
    :custom_apps, :custom_ticket_fields, :custom_company_fields, :custom_contact_fields,
    :occasional_agent, :allow_auto_suggest_solutions, :basic_twitter, :basic_facebook,
    :multi_product, :multiple_business_hours, :multi_timezone, :customer_slas,
    :layout_customization, :advanced_reporting, :timesheets, :multiple_emails,
    :custom_domain, :gamification, :gamification_enable, :auto_refresh, :branding,
    :advanced_dkim, :basic_dkim, :system_observer_events, :unique_contact_identifier,
    :ticket_activity_export, :caching, :private_inline, :collaboration, :multi_dynamic_sections,
    :skill_based_round_robin, :auto_ticket_export, :user_notifications, :falcon,
    :multiple_companies_toggle, :multiple_user_companies, :denormalized_flexifields,
    :custom_dashboard, :support_bot, :image_annotation, :tam_default_fields, :undo_send,
    :todos_reminder_scheduler, :smart_filter, :ticket_summary, :opt_out_analytics,
    :freshchat, :disable_old_ui, :contact_company_notes, :sandbox, :parent_child_infra,
    :session_replay, :segments, :freshconnect, :proactive_outreach, :audit_logs_central_publish,
    :audit_log_ui, :omni_channel_routing, :custom_encrypted_fields, :hipaa,
    :canned_forms, :custom_translations, :social_tab,
    :customize_table_view, :public_url_toggle, :add_to_response, :agent_scope,
    :performance_report, :custom_password_policy, :social_tab, :scenario_automation,
    :omni_channel, :ticket_volume_report, :sla_management_v2, :api_v2, :cascade_dispatcher,
    :personal_canned_response, :marketplace, :reverse_notes,
    :freshreports_analytics, :disable_old_reports, :article_filters, :adv_article_bulk_actions,
    :auto_article_order, :detect_thank_you_note, :detect_thank_you_note_eligible, :proactive_spam_detection
  ].concat(ADVANCED_FEATURES + ADVANCED_FEATURES_TOGGLE + HelpdeskReports::Constants::FreshvisualFeatureMapping::REPORTS_FEATURES_LIST).uniq
  # Doing uniq since some REPORTS_FEATURES_LIST are present in Bitmap. Need REPORTS_FEATURES_LIST to check if reports related Bitmap changed.

  COMBINED_VERSION_ENTITY_KEYS = [
    Helpdesk::TicketField::VERSION_MEMBER_KEY,
    ContactField::VERSION_MEMBER_KEY,
    CompanyField::VERSION_MEMBER_KEY,
    CustomSurvey::Survey::VERSION_MEMBER_KEY,
    Freshchat::Account::VERSION_MEMBER_KEY,
    AgentGroup::VERSION_MEMBER_KEY
  ]

  PODS_FOR_BOT = ['poduseast1'].freeze

  PRICING_PLAN_MIGRATION_FEATURES_2019 = [:social_tab, :customize_table_view,
    :public_url_toggle, :add_to_response, :agent_scope, :performance_report,
    :custom_password_policy, :scenario_automation, :sla_management_v2, :omni_channel, :api_v2,
    :personal_canned_response, :marketplace, :fa_developer].to_set.freeze

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

  # TODO: Remove new_pricing_launched?() after 2019 pricing plan launch
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

  # TODO: Remove on_new_plan?() after 2019 pricing plan launch
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

  def fsm_addon_billing_enabled?
    @fsm_addon_billing ||= disable_old_ui_enabled? && addon_based_billing_enabled?
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
    hash_set = Hash[COMBINED_VERSION_ENTITY_KEYS.collect { |key| [key.to_s, Time.now.utc.to_i] }]
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

  def new_onboarding_enabled?
    launched?(:new_onboarding) || launched?(:onboarding_v2)
  end

  def bitmap_feature_changed?(feature_val)
    old_feature = self.changes[:plan_features][0].to_i
    new_feature = self.changes[:plan_features][1].to_i
    return false if ((old_feature ^ new_feature) & (2**feature_val)).zero?
    @action = (old_feature & (2**feature_val)).zero? ? "add" : "drop"
  end

  def custom_translations_enabled?
    redis_picklist_id_enabled? && has_feature?(:custom_translations)
  end

  def undo_send_enabled?
    has_feature?(:undo_send) || launched?(:undo_send)
  end

  def email_spoof_check_feature?
    email_spoof_check_enabled? && !disable_email_spoof_check_enabled?
  end

  def automatic_ticket_assignment_enabled?
    features?(:round_robin) || features?(:round_robin_load_balancing) ||
      skill_based_round_robin_enabled? || omni_channel_routing_enabled?
  end

  # Need to cleanup bellow code snippet with 2019 plan changes release
  # START
  def has_feature?(feature)
    return super if launched?(:pricing_plan_change_2019)
    PRICING_PLAN_MIGRATION_FEATURES_2019.include?(feature) ? true : super
  end

  def features_list
    return super if launched?(:pricing_plan_change_2019)
    (super + PRICING_PLAN_MIGRATION_FEATURES_2019.to_a).uniq
  end

  def has_features?(*features)
    unless launched?(:pricing_plan_change_2019)
      features.delete_if { |feature| PRICING_PLAN_MIGRATION_FEATURES_2019.include?(feature) }
    end
    super
  end

  def latest_notes_first_enabled?(current_user = :no_user)
    !oldest_notes_first_enabled?(current_user)
  end

  def oldest_notes_first_enabled?(current_user = :no_user)
    return true unless reverse_notes_enabled?
    user_settings = current_user.old_notes_first? if current_user != :no_user
    user_settings.nil? ? account_additional_settings.old_notes_first? : user_settings
  end

  def detect_thank_you_note_enabled?
    detect_thank_you_note_eligible_enabled? && has_feature?(:detect_thank_you_note)
  end
  # STOP
end
