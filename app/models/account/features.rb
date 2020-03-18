class Account < ActiveRecord::Base

  LP_FEATURES = [
    :select_all, :round_robin_capping, :suggest_tickets, :field_agent_availability,
    :customer_sentiment_ui, :dkim, :dkim_email_service, :scheduled_ticket_export,
    :ticket_contact_export, :email_failures, :disable_emails, :facebook_page_redirect,
    :falcon_portal_theme, :freshid, :freshchat_integration, :allow_huge_ccs,
    :ticket_central_publish, :company_central_publish, :solutions_central_publish,
    :outgoing_attachment_limit_25, :incoming_attachment_limit_25,
    :whitelist_sso_login, :admin_only_mint, :customer_notes_s3, :announcements_tab,
    :imap_error_status_check, :va_any_field_without_none, :api_es,
    :encode_emoji, :auto_complete_off, :sandbox_lp, :note_central_publish,
    :dependent_field_validation, :post_central_publish, :encode_emoji_subject,
    :euc_migrated_twitter, :new_ticket_recieved_metric, :ner,
    :dashboard_announcement_central_publish, :disable_banners,
    :count_service_es_writes, :count_service_es_reads, :time_sheets_central_publish,
    :sso_login_expiry_limitation, :undo_send, :old_link_back_url_validation, :stop_contacts_count_query,
    :denormalized_select_for_update, :installed_app_publish, :es_tickets,
    :whitelist_supervisor_sla_limitation, :es_msearch, :year_in_review_2017,:year_in_review_and_share,
    :onboarding_inlinemanual, :skip_portal_cname_chk,
    :product_central_publish, :help_widget, :redis_picklist_id,
    :bot_email_channel, :bot_email_central_publish, :description_by_default,
    :bot_chat_history, :new_es_api, :filter_factory, :ticket_fields_central_publish,
    :skip_invoice_due_warning, :automation_revamp, :archive_ticket_fields,
    :scheduled_export_fix, :compact_lang_detection,
    :agent_group_central_publish, :custom_fields_search,
    :update_billing_info, :allow_billing_info_update, :tag_central_publish,
    :native_apps, :archive_tickets_api, :bot_agent_response,
    :fetch_ticket_from_ref_first, :query_from_singleton, :surveys_central_publish,
    :id_for_choices_write, :fluffy, :session_logs, :nested_field_revamp, :service_worker, :kbase_mint,
    :freshvisual_configs, :ticket_field_limit_increase, :join_ticket_field_data, :bypass_signup_captcha,
    :simple_outreach, :disable_simple_outreach, :supervisor_text_field, :disable_mint_analytics,
    :freshid_org_v2, :hide_agent_login, :office365_adaptive_card, :facebook_admin_ui_revamp,
    :text_custom_fields_in_etl, :email_spoof_check, :disable_email_spoof_check, :webhook_blacklist_ip,
    :recalculate_daypass, :fb_page_api_improvement, :attachment_redirect_expiry, :contact_company_split,
    :solutions_agent_portal, :solutions_agent_metrics, :fuzzy_search, :delete_trash_daily,
    :prevent_wc_ticket_create, :allow_wildcard_ticket_create, :requester_privilege,
    :prevent_parallel_update, :sso_unique_session, :delete_trash_daily_schedule, :retrigger_lbrr, :fsm_admin_automations,
    :csat_email_scan_compatibility, :mint_portal_applicable, :quoted_text_parsing_feature, :enable_customer_journey,
    :email_mailbox, :sandbox_temporary_offset, :downgrade_policy, :article_es_search_by_filter,
    :fluffy_min_level, :allow_update_agent, :help_widget_solution_categories, :optar_cache, :fsm_custom_to_default_filter, :launch_fsm_geolocation,
    :ticket_field_revamp, :facebook_dm_outgoing_attachment, :skip_posting_to_fb, :hide_mailbox_error_from_agents, :hide_og_meta_tags,
    :freshcaller_admin_new_ui, :facebook_post_outgoing_attachment, :incoming_mentions_in_tms, :disable_occlusion_rendering,
    :prevent_lang_detect_for_spam, :jira_onpremise_reporter, :support_ticket_rate_limit, :sidekiq_logs_to_central, :portal_central_publish, :encode_emoji_in_solutions,
    :forums_agent_portal, :agent_shifts, :mailbox_google_oauth, :helpdesk_tickets_by_product, :migrate_euc_pages_to_us, :agent_collision_revamp, :topic_editor_with_html,
    :mailbox_forward_setup, :remove_image_attachment_meta_data, :automated_private_notes_notification, :detect_lang_from_email_service,
    :sane_restricted_helpdesk, :hiding_confidential_logs, :ticket_list_performance, :sla_policy_revamp, :help_widget_log, :freshdesk_freshsales_bundle, :help_widget_article_customisation,
    :field_agents_can_manage_appointments_setting, :fsm_for_garden_plan, :fsm_for_blossom_plan, :requester_widget_timeline,
    :out_of_office, :enable_secure_login_check, :contact_form_enhancement, :public_api_filter_factory, :enable_twitter_requester_fields, :marketplace_gallery, :solutions_quick_view,
    :translations_proxy, :translations_cdn, :facebook_public_api, :twitter_public_api, :emberize_agent_form, :retry_emails, :enable_beamer, :fb_message_echo_support, :portal_prototype_update,
    :bot_banner
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
    :sandbox, :session_replay, :segments, :freshconnect, :proactive_outreach,
    :audit_logs_central_publish, :audit_log_ui, :omni_channel_routing, :undo_send,
    :custom_encrypted_fields, :custom_translations, :parent_child_infra,
    :canned_forms, :customize_table_view, :public_url_toggle,
    :add_to_response, :agent_scope, :performance_report, :custom_password_policy,
    :social_tab, :unresolved_tickets_widget_for_sprout, :scenario_automation,
    :ticket_volume_report, :omni_channel, :sla_management_v2, :api_v2, :cascade_dispatcher,
    :personal_canned_response, :marketplace, :reverse_notes, :field_service_geolocation, :field_service_geolocation_toggle,
    :freshreports_analytics, :disable_old_reports, :article_filters, :adv_article_bulk_actions,
    :auto_article_order, :detect_thank_you_note, :detect_thank_you_note_eligible, :autofaq, :proactive_spam_detection,
    :ticket_properties_suggester, :ticket_properties_suggester_eligible,
    :hide_first_response_due, :agent_articles_suggest, :email_articles_suggest, :customer_journey, :botflow,
    :help_widget, :help_widget_appearance, :help_widget_predictive, :portal_article_filters, :supervisor_custom_status, :lbrr_by_omniroute,
    :secure_attachments, :article_versioning, :article_export, :article_approval_workflow, :next_response_sla, :advanced_automations,
    :fb_ad_posts, :suggested_articles_count, :unlimited_multi_product, :solutions_freshconnect,
    :help_widget_article_customisation, :agent_assist, :sla_reminder_automation, :article_interlinking, :pci_compliance_field
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

  PRICING_PLAN_MIGRATION_FEATURES_2020 = [
    :unlimited_multi_product, :sla_reminder_automation
  ].to_set.freeze

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
    features_migrated_to_bmp = Account.handle_feature_name_change(feature_names &
      DB_TO_BITMAP_MIGRATION_P2_FEATURES_LIST)
    features_migrated_to_lp = feature_names & DB_TO_LP_MIGRATION_P2_FEATURES_LIST
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

  def supervisor_custom_status_enabled?
    launched?(:supervisor_custom_status) || has_feature?(:supervisor_custom_status)
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

  def count_public_api_filter_factory_enabled?
    public_api_filter_factory_enabled? && new_es_api_enabled? && count_service_es_reads_enabled?
  end

  def count_es_enabled?
    launched?(:count_service_es_reads) ||
      ((launched?(:es_count_reads) || launched?(:list_page_new_cluster)) &&
        features?(:countv2_reads))
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
    launched?(:customer_sentiment)
  end

  def freshfone_enabled?
    features?(:freshfone) and freshfone_account.present?
  end

  def freshcaller_enabled?
    has_feature?(:freshcaller) and freshcaller_account.present?
  end

  def freshcaller_admin_new_ui_enabled?
    has_feature?(:freshcaller) and launched?(:freshcaller_admin_new_ui)
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
    hash_set = Hash[COMBINED_VERSION_ENTITY_KEYS.collect { |key| [key.to_s, Time.now.utc.to_i] }]
    set_others_redis_hash(version_key, hash_set)
  end

  def support_bot_configured?
    support_bot_enabled? && bot_onboarded?
  end

  def revoke_support_bot?
    redis_key_exists?(REVOKE_SUPPORT_BOT) || (Rails.env.production? && PODS_FOR_BOT.exclude?(PodConfig['CURRENT_POD']))
  end

  def undo_send_enabled?
    has_feature?(:undo_send) || launched?(:undo_send)
  end

  def email_spoof_check_feature?
    email_spoof_check_enabled? && !disable_email_spoof_check_enabled?
  end

  def help_widget_enabled?
    launched?(:help_widget) && has_feature?(:help_widget)
  end

  def help_widget_article_customisation_enabled?
    launched?(:help_widget_article_customisation) && has_feature?(:help_widget_article_customisation)
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
    redis_picklist_id_enabled? && has_feature?(:custom_translations)
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
    DB_TO_LP_MIGRATION_P2_FEATURES_LIST.include? fname
  end

  def launched_db_feature
    DB_TO_LP_MIGRATION_P2_FEATURES_LIST.select { |f| launched?(f) }
  end
  # TODO : Cleanup up after 2020 pricing changes
  # START
  def has_feature?(feature)
    return super if launched?(:pricing_plan_change_2020)

    PRICING_PLAN_MIGRATION_FEATURES_2020.include?(feature) ? true : super
  end

  def features_list
    return super if launched?(:pricing_plan_change_2020)

    (super + PRICING_PLAN_MIGRATION_FEATURES_2020.to_a).uniq
  end

  def has_features?(*features)
    unless launched?(:pricing_plan_change_2020)
      features.delete_if { |feature| PRICING_PLAN_MIGRATION_FEATURES_2020.include?(feature) }
    end
    super
  end
  # STOP

  def ticket_properties_suggester_enabled?
    ticket_properties_suggester_eligible_enabled? && has_feature?(:ticket_properties_suggester)
  end

  def detect_thank_you_note_enabled?
    detect_thank_you_note_eligible_enabled? && has_feature?(:detect_thank_you_note)
  end

  def features
    Account::ProxyFeature::ProxyFeatureAssociation.new(self)
  end
end
