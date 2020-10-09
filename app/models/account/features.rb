class Account < ActiveRecord::Base

  FRONTEND_LP_FEATURES = [
    :bot_canned_response
  ].freeze

  LP_FEATURES = [
    :spam_blacklist_feature,
    :suggest_tickets, :customer_sentiment_ui, :dkim, :dkim_email_service, :feature_based_settings,
    :scheduled_ticket_export, :ticket_contact_export, :disable_emails,
    :falcon_portal_theme, :freshid, :allow_huge_ccs, :email_new_settings, :kbase_spam_whitelist,
    :outgoing_attachment_limit_25, :incoming_attachment_limit_25,
    :whitelist_sso_login, :admin_only_mint, :customer_notes_s3, :va_any_field_without_none, :api_es,
    :auto_complete_off, :new_ticket_recieved_metric, :ner, :count_service_es_reads,
    :sso_login_expiry_limitation, :old_link_back_url_validation, :stop_contacts_count_query,
    :es_tickets, :fb_msg_realtime,
    :whitelist_supervisor_sla_limitation, :es_msearch, :year_in_review_2017,:year_in_review_and_share,
    :skip_portal_cname_chk, :ticket_source_revamp, :custom_product_notification,
    :bot_email_channel, :description_by_default, :bot_chat_history,
    :archive_ticket_fields, :custom_fields_search, :disable_rabbitmq_iris,
    :update_billing_info, :allow_billing_info_update,
    :native_apps, :archive_tickets_api, :bot_agent_response,
    :id_for_choices_write, :fluffy, :fluffy_email, :fluffy_email_signup, :session_logs, :nested_field_revamp,
    :ticket_field_limit_increase, :join_ticket_field_data,
    :disable_simple_outreach, :supervisor_text_field, :disable_mint_analytics,
    :freshid_org_v2, :hide_agent_login,
    :text_custom_fields_in_etl, :email_spoof_check, :disable_email_spoof_check, :webhook_blacklist_ip,
    :recalculate_daypass, :attachment_redirect_expiry, :contact_company_split,
    :fuzzy_search, :delete_trash_daily,
    :requester_privilege, :disable_archive,
    :prevent_parallel_update, :sso_unique_session, :delete_trash_daily_schedule, :retrigger_lbrr, :asset_management,
    :csat_email_scan_compatibility, :mint_portal_applicable, :quoted_text_parsing_feature,
    :sandbox_temporary_offset, :downgrade_policy, :article_es_search_by_filter,
    :fluffy_min_level, :allow_update_agent, :launch_fsm_geolocation, :geolocation_historic_popup, :helpdesk_new_settings,
    :ticket_field_revamp, :hide_mailbox_error_from_agents, :hide_og_meta_tags, :disable_occlusion_rendering,
    :jira_onpremise_reporter, :sidekiq_logs_to_central, :encode_emoji_in_solutions,
    :agent_shifts, :mailbox_google_oauth, :migrate_euc_pages_to_us, :agent_collision_revamp, :topic_editor_with_html,
    :remove_image_attachment_meta_data, :automated_private_notes_notification,
    :sane_restricted_helpdesk, :hiding_confidential_logs, :help_widget_log,
    :requester_widget_timeline, :sprout_trial_onboarding,
    :out_of_office, :enable_secure_login_check, :public_api_filter_factory, :marketplace_gallery,
    :translations_proxy, :facebook_public_api, :twitter_public_api, :emberize_agent_form, :disable_beamer, :fb_message_echo_support, :portal_prototype_update,
    :bot_banner, :idle_session_timeout, :solutions_dashboard, :block_spam_user,
    :observer_race_condition_fix, :contact_graphical_avatar, :omni_bundle_2020, :article_versioning_redis_lock, :freshid_sso_sync, :fw_sso_admin_security, :cre_account, :cdn_attachments,
    :omni_chat_agent, :portal_frameworks_update, :ticket_filters_central_publish, :new_email_regex, :auto_refresh_revamp, :agent_statuses, :omni_reports, :freddy_subscription, :omni_channel_team_dashboard, :filter_facebook_mentions,
    :omni_plans_migration_banner, :parse_replied_email, :wf_comma_filter_fix, :composed_email_check, :omni_channel_dashboard, :csat_for_social_surveymonkey, :fresh_parent, :trim_special_characters, :kbase_omni_bundle,
    :omni_agent_availability_dashboard, :twitter_api_compliance, :silkroad_export, :silkroad_shadow, :silkroad_multilingual, :group_management_v2, :symphony, :invoke_touchstone, :explore_omnichannel_feature, :hide_omnichannel_toggle,
    :dashboard_java_fql_performance_fix, :emberize_business_hours, :chargebee_omni_upgrade, :ticket_observer_race_condition_fix, :csp_reports, :show_omnichannel_nudges, :whatsapp_ticket_source, :chatbot_ui_revamp, :response_time_null_fix, :cx_feedback, :export_ignore_primary_key, :archive_ticket_central_publish,
    :archive_on_missing_associations, :mailbox_ms365_oauth, :pre_compute_ticket_central_payload, :security_revamp, :channel_command_reply_to_sidekiq, :ocr_to_mars_api, :supervisor_contact_field, :forward_to_phone, :html_to_plain_text, :freshcaller_ticket_revamp, :get_associates_from_db,
    :force_index_tickets, :es_v2_splqueries, :launch_kbase_omni_bundle, :cron_api_trigger, :redirect_helpdesk_ticket_index, :redirect_helpdesk_ticket_new, :redirect_helpdesk_ticket_compose_email, :redirect_helpdesk_ticket_edit,
    :redirect_contact_new, :redirect_contact_edit, :redirect_contact_index, :redirect_companies_new, :redirect_companies_edit, :redirect_companies_index, :redirect_companies_show,
    :redirect_archive_tickets_new, :redirect_archive_tickets_show, :redirect_archive_tickets_edit, :redirect_archive_tickets_index, :redirect_old_ui_paths
  ].concat(FRONTEND_LP_FEATURES).uniq

  BITMAP_FEATURES = [
    :allow_huge_ccs,
    :custom_survey, :requester_widget, :split_tickets, :add_watcher, :traffic_cop,
    :custom_ticket_views, :supervisor, :archive_tickets, :sitemap, :kbase_spam_whitelist,
    :create_observer, :sla_management, :email_commands, :assume_identity, :rebranding,
    :custom_apps, :custom_ticket_fields, :custom_company_fields, :custom_contact_fields,
    :occasional_agent, :allow_auto_suggest_solutions, :basic_twitter, :basic_facebook,
    :multi_product, :multiple_business_hours, :multi_timezone, :customer_slas,
    :layout_customization, :advanced_reporting, :timesheets, :multiple_emails,
    :custom_domain, :gamification, :gamification_enable, :auto_refresh, :branding_feature,
    :advanced_dkim, :basic_dkim, :system_observer_events, :unique_contact_identifier,
    :ticket_activity_export, :caching, :private_inline, :collaboration, :hipaa,
    :dynamic_sections, :skill_based_round_robin, :auto_ticket_export, :custom_product_notification,
    :user_notifications, :falcon, :multiple_companies_toggle, :multiple_user_companies,
    :denormalized_flexifields, :custom_dashboard, :support_bot, :image_annotation,
    :tam_default_fields, :todos_reminder_scheduler, :smart_filter,
    :opt_out_analytics, :freshchat, :disable_old_ui, :contact_company_notes,
    :sandbox, :session_replay, :segments, :freshconnect, :proactive_outreach,
    :audit_logs_central_publish, :audit_log_ui, :omni_channel_routing, :undo_send,
    :custom_encrypted_fields, :custom_translations, :parent_child_infra, :custom_source,
    :canned_forms, :customize_table_view, :solutions_templates, :fb_msg_realtime,
    :add_to_response, :agent_scope, :performance_report, :custom_password_policy,
    :social_tab, :unresolved_tickets_widget_for_sprout, :scenario_automation,
    :ticket_volume_report, :omni_channel, :sla_management_v2, :api_v2,
    :personal_canned_response, :marketplace, :reverse_notes, :field_service_geolocation, :spam_blacklist_feature,
    :location_tagging, :freshreports_analytics, :disable_old_reports, :article_filters, :adv_article_bulk_actions,
    :auto_article_order, :detect_thank_you_note, :detect_thank_you_note_eligible, :autofaq, :proactive_spam_detection,
    :ticket_properties_suggester, :ticket_properties_suggester_eligible, :disable_archive,
    :hide_first_response_due, :agent_articles_suggest, :agent_articles_suggest_eligible, :email_articles_suggest, :customer_journey, :botflow,
    :help_widget, :help_widget_appearance, :help_widget_predictive, :portal_article_filters, :supervisor_custom_status, :lbrr_by_omniroute,
    :secure_attachments, :article_versioning, :article_export, :article_approval_workflow, :next_response_sla, :advanced_automations,
    :fb_ad_posts, :suggested_articles_count, :unlimited_multi_product, :freddy_self_service, :freddy_ultimate,
    :help_widget_article_customisation, :agent_assist_lite, :sla_reminder_automation, :article_interlinking, :pci_compliance_field, :kb_increased_file_limit,
    :twitter_field_automation, :robo_assist, :triage, :advanced_article_toolbar_options, :advanced_freshcaller, :email_bot, :agent_assist_ultimate, :canned_response_suggest, :robo_assist_ultimate, :advanced_ticket_scopes,
    :custom_objects, :quality_management_system, :triage_ultimate, :autofaq_eligible, :whitelisted_ips, :solutions_agent_metrics_feature, :forums_agent_portal, :solutions_agent_portal,
    :supervisor_contact_field, :whatsapp_channel, :sidekiq_logs_to_central,
    :basic_settings_feature, :skip_portal_cname_chk, :stop_contacts_count_query, :force_index_tickets, :es_v2_splqueries, :disable_emails, :ticket_filter_increased_companies_limit,
    :csat_email_scan_compatibility
  ].concat(ADVANCED_FEATURES + ADVANCED_FEATURES_TOGGLE + HelpdeskReports::Constants::FreshvisualFeatureMapping::REPORTS_FEATURES_LIST).uniq
  # Doing uniq since some REPORTS_FEATURES_LIST are present in Bitmap. Need REPORTS_FEATURES_LIST to check if reports related Bitmap changed.

  LP_TO_BITMAP_MIGRATION_FEATURES = [
    :custom_product_notification,
    :allow_huge_ccs,
    :fb_msg_realtime,
    :spam_blacklist_feature,
    :kbase_spam_whitelist,
    :supervisor_contact_field,
    :disable_archive,
    :skip_portal_cname_chk,
    :sidekiq_logs_to_central,
    :stop_contacts_count_query,
    :force_index_tickets,
    :es_v2_splqueries,
    :disable_emails,
    :csat_email_scan_compatibility
  ].freeze

  COMBINED_VERSION_ENTITY_KEYS = [
    Helpdesk::TicketField::VERSION_MEMBER_KEY,
    ContactField::VERSION_MEMBER_KEY,
    CompanyField::VERSION_MEMBER_KEY,
    CustomSurvey::Survey::VERSION_MEMBER_KEY,
    Freshchat::Account::VERSION_MEMBER_KEY,
    AgentGroup::VERSION_MEMBER_KEY
  ]

  PODS_FOR_BOT = ['poduseast1'].freeze

  LAUNCH_PARTY_FEATURES_TO_LOG = [
    :admin_only_mint, :falcon
  ].freeze

  BITMAP_FEATURES_TO_LOG = [
    :falcon, :disable_old_ui
  ].freeze

  def launched?(*feature_name)
    features_list = feature_name & LAUNCH_PARTY_FEATURES_TO_LOG

    if features_list.present?
      features_list.each do |feature|
        log_feature_usage(feature)
        feature_name.delete(feature)
      end
    end

    super
  end

  def log_feature_usage(feature_name)
    Rails.logger.warn "FEATURE CHECK USAGE :: #{feature_name} :: #{caller[0..5]}"
    true
  end

  LP_FEATURES.each do |item|
    define_method "#{item.to_s}_enabled?" do
      launched?(item)
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

  # To check if a bitmap feature changed
  # Use this for after_update hook
  Fdadmin::FeatureMethods::BITMAP_FEATURES_WITH_VALUES.each do |key, value|
    define_method "#{key.to_s}_feature_changed?" do
      self.changes[:plan_features].present? && bitmap_feature_changed?(value)
    end
  end

  # To check if a bitmap feature changed
  # Use this for after_commit hook
  Fdadmin::FeatureMethods::BITMAP_FEATURES_WITH_VALUES.each do |key, value|
    define_method "#{key}_feature_toggled?" do
      previous_changes[:plan_features].present? && bitmap_feature_toggled?(value)
    end
  end

  def features?(*feature_names)
    feature_names = feature_names.to_set
    features_migrated_to_bmp = Account.handle_feature_name_change(feature_names - DB_TO_LP_FEATURES)
    features_migrated_to_lp = feature_names & DB_TO_LP_FEATURES
    has_features?(*features_migrated_to_bmp) && launched?(*features_migrated_to_lp)
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

  def spam_blacklist_feature_enabled?
    launched?(:spam_blacklist_feature)
  end

  def count_public_api_filter_factory_enabled?
    public_api_filter_factory_enabled? && new_es_api_enabled? && count_service_es_reads_enabled?
  end

  def count_es_enabled?
    launched?(:count_service_es_reads)
  end

  def count_es_api_enabled?
    count_es_enabled? && api_es_enabled?
  end

  def count_es_tickets_enabled?
    count_es_enabled? && es_tickets_enabled?
  end

  def customer_sentiment_enabled?
    launched?(:customer_sentiment)
  end

  def freshcaller_enabled?
    has_feature?(:freshcaller) and freshcaller_account.present?
  end

  def freshchat_linked?
    has_feature?(:freshchat) && freshchat_account.try(:enabled)
  end

  def omni_chat_agent_enabled?
    launched?(:omni_chat_agent) && freshchat_linked? && freshid_integration_enabled?
  end

  def livechat_enabled?
    features?(:chat) and !chat_setting.site_id.blank?
  end

  def freshchat_routing_enabled?
    livechat_enabled? and features?(:chat_routing)
  end

  def fb_msg_realtime_enabled?
    launched?(:fb_msg_realtime)
  end

  def supervisor_feature_launched?
    features?(:freshfone_call_monitoring) || features?(:agent_conference)
  end

  def helpdesk_restriction_enabled?
    features?(:helpdesk_restriction_toggle) || launched?(:restricted_helpdesk)
  end

  def dashboard_disabled?
    ismember?(DASHBOARD_DISABLED, self.id)
  end

  def restricted_compose_enabled?
    ismember?(RESTRICTED_COMPOSE, self.id)
  end

  def hide_agent_metrics_feature?
    features?(:euc_hide_agent_metrics)
  end

  def advance_facebook_enabled?
    features?(:facebook)
  end

  def advanced_twitter?
    features? :twitter
  end

  def twitter_smart_filter_revoked?
    redis_key_exists?(TWITTER_SMART_FILTER_REVOKED) && smart_filter_enabled? && !Account.current.twitter_handles_from_cache.blank?
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
    Rails.logger.warn "FALCON FEATURE METHOD :: falcon_ui_enabled? :: #{caller[0..2]}"
    return true if current_user
  end

  alias falcon_support_portal_theme_enabled? falcon_portal_theme_enabled?

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

  def email_spoof_check_feature?
    email_spoof_check_enabled? && !disable_email_spoof_check_enabled?
  end

  # Checks if a bitmap feature has been added or removed after_update
  # old_feature ^ new_feature - Will give the list of all features that have been modified in update call
  # (old_feature ^ new_feature) & (2**feature_val) - Will return zero if the given feature has not been modified
  # old_feature & (2**feature_val) - Checks if the given feature is part of old_feature. If so, the feature has been removed. Else,it's been added.
  def bitmap_feature_changed?(feature_val)
    old_feature = self.changes[:plan_features][0].to_i
    new_feature = self.changes[:plan_features][1].to_i
    return false if ((old_feature ^ new_feature) & (2**feature_val)).zero?
    @action = (old_feature & (2**feature_val)).zero? ? "add" : "drop"
  end

  # Checks if a bitmap feature has been added or removed after_commit
  # old_feature ^ new_feature - Will give the list of all features that have been modified in update call
  # (old_feature ^ new_feature) & (2**feature_val) - Will return zero if the given feature has not been modified
  def bitmap_feature_toggled?(feature_val)
    old_feature = previous_changes[:plan_features][0].to_i
    new_feature = previous_changes[:plan_features][1].to_i
    return true unless ((old_feature ^ new_feature) & (2**feature_val)).zero?
  end

  def custom_translations_enabled?
    has_feature?(:custom_translations)
  end

  def automatic_ticket_assignment_enabled?
    features?(:round_robin) || features?(:round_robin_load_balancing) ||
      skill_based_round_robin_enabled? || omni_channel_routing_enabled?
  end

  def latest_notes_first_enabled?(current_user = :no_user)
    !oldest_notes_first_enabled?(current_user)
  end

  def oldest_notes_first_enabled?(current_user = :no_user)
    return true unless reverse_notes_enabled?
    user_settings = current_user.old_notes_first? if current_user != :no_user
    user_settings.nil? ? account_additional_settings.old_notes_first? : user_settings
  end

  def bitmap_feature_name(fname)
    FEATURE_NAME_CHANGES[fname] || fname
  end

  def db_to_lp?(fname)
    DB_TO_LP_FEATURES.include? fname
  end

  def launched_db_feature
    DB_TO_LP_FEATURES.select { |f| launched?(f) }
  end

  def central_publish_account_features
    features_list + launched_central_publish_features
  end

  def launched_central_publish_features
    # intersection of launched features and central publish lp features
    all_launched_features & CENTRAL_PUBLISH_LAUNCHPARTY_FEATURES.keys
  end

  def ticket_properties_suggester_enabled?
    ticket_properties_suggester_eligible_enabled? && has_feature?(:ticket_properties_suggester)
  end

  def detect_thank_you_note_enabled?
    detect_thank_you_note_eligible_enabled? && has_feature?(:detect_thank_you_note)
  end

  def omni_channel_dashboard_enabled?
    omni_bundle_account? && launched?(:omni_channel_dashboard)
  end

  def omni_channel_team_dashboard_enabled?
    omni_bundle_account? && launched?(:omni_channel_team_dashboard)
  end

  def custom_product_notification_enabled?
    launched?(:custom_product_notification)
  end

  def sidekiq_logs_to_central_enabled?
    launched?(:sidekiq_logs_to_central)
  end

  def kbase_spam_whitelist_enabled?
    launched?(:kbase_spam_whitelist)
  end

  def csat_email_scan_compatibility_enabled?
    launched?(:csat_email_scan_compatibility)
  end

  def features
    Account::ProxyFeature::ProxyFeatureAssociation.new(self)
  end
end
