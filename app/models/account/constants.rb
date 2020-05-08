class Account < ActiveRecord::Base

  DEFAULT_IN_OPERATOR_FIELDS = {
    :ticket =>   ["priority", "ticket_type", "status", "source", "product_id", "responder_id", "group_id"] ,
    :requester => ["time_zone", "language"],
    :company => ["name"]
  }

  RESERVED_DOMAINS = %W(  blog help chat smtp mail www ftp imap pop faq docs doc team people india us talk
                          upload download info lounge community forums ticket tickets tour about pricing bugs in out
                          logs projects itil marketing store channel reseller resellers online
                          contact admin #{AppConfig['admin_subdomain']} girish shan vijay parsu kiran shihab
                          productdemo resources static static0 static1 static2 static3 static4 static5
                          static6 static7 static8 static9 static10 dev apps freshapps fone shift
                          elb elb1 elb2 elb3 elb4 elb5 elb6 elb7 elb8 elb9 elb10 agent-hermes
                          attachment euattachment eucattachment ausattachment indattachment cobrowsing migrations
                          migrations-eu migrations-au migrations-ind authz authz-euc authz-ind authz-au ipaas-tool
                          ipaas-app ipaas-ui) + FreshopsSubdomains + PartnerSubdomains

  PLANS_AND_FEATURES = {
    :basic => { :features => [ :twitter, :custom_domain, :multiple_emails, :marketplace ] },

    :pro => {
      :features => [ :gamification, :scenario_automations, :customer_slas, :business_hours, :forums,
        :surveys, :scoreboard, :facebook, :timesheets, :css_customization, :advanced_reporting ],
      :inherits => [ :basic ]
    },

    :premium => {
      :features => [ :multi_product, :multi_timezone , :multi_language, :enterprise_reporting, :dynamic_content],
      :inherits => [ :pro ] #To make the hierarchy easier
    },

    sprout: {
      features: [:scenario_automations, :business_hours, :marketplace, :help_widget]
    },

    blossom: {
      features: [:gamification, :auto_refresh, :twitter, :facebook, :forums, :surveys, :scoreboard, :timesheets,
                 :custom_domain, :multiple_emails, :advanced_reporting, :default_survey, :sitemap, :requester_widget,
                 :help_widget_appearance],
      inherits: [:sprout]
    },

    garden: {
      features: [:multi_product, :customer_slas, :multi_timezone, :multi_language,
                 :css_customization, :advanced_reporting, :multiple_business_hours, :dynamic_content,
                 :ticket_templates, :custom_survey, :help_widget_predictive],
      inherits: [:blossom]
    },

    :estate => {
      :features => [ :collision, :layout_customization, :round_robin, :enterprise_reporting,
        :custom_ssl, :custom_roles, :multiple_business_hours, :dynamic_sections,
        :helpdesk_restriction_toggle, :round_robin_load_balancing, :multiple_user_companies,
        :multiple_companies_toggle, :round_robin_on_update, :multi_dynamic_sections ],
      :inherits => [ :garden ]
    },

    :forest => {
      :features => [ :mailbox, :whitelisted_ips, :skill_based_round_robin ],
      :inherits => [ :estate ]
    },

    sprout_classic: {
      features: [:scenario_automations, :business_hours, :custom_domain, :multiple_emails, :marketplace, :help_widget]
    },

    blossom_classic: {
      features: [:gamification, :auto_refresh, :twitter, :facebook, :forums, :surveys,
                 :scoreboard, :timesheets, :advanced_reporting, :help_widget_appearance],
      inherits: [:sprout_classic]
    },

    garden_classic: {
      features: [:multi_product, :customer_slas, :multi_timezone, :multi_language,
                 :css_customization, :advanced_reporting, :dynamic_content, :ticket_templates, :help_widget_predictive],
      inherits: [:blossom_classic]
    },

    :estate_classic => {
      :features => [ :collision, :layout_customization, :round_robin, :enterprise_reporting,
        :custom_ssl, :custom_roles, :multiple_business_hours, :dynamic_sections,
        :helpdesk_restriction_toggle, :round_robin_load_balancing, :multiple_user_companies,
        :multiple_companies_toggle, :round_robin_on_update, :multi_dynamic_sections ],
      :inherits => [ :garden_classic ]
    },

    sprout_jan_17: {
      features: [:scenario_automations, :business_hours, :marketplace, :help_widget]
    },

    blossom_jan_17: {
      features: [:gamification, :auto_refresh, :twitter, :facebook, :surveys, :scoreboard, :timesheets,
                 :custom_domain, :multiple_emails, :advanced_reporting, :default_survey, :sitemap,
                 :requester_widget, :help_widget_appearance],
      inherits: [:sprout_jan_17]
    },

    garden_jan_17: {
      features: [:forums, :multi_language, :css_customization, :advanced_reporting, :dynamic_content,
                 :ticket_templates, :custom_survey, :help_widget_predictive],
      inherits: [:blossom_jan_17]
    },

    :estate_jan_17 => {
      :features => [ :multi_product, :customer_slas, :multi_timezone ,
        :collision, :layout_customization, :round_robin, :enterprise_reporting,
        :custom_ssl, :custom_roles, :multiple_business_hours, :dynamic_sections,
        :helpdesk_restriction_toggle, :round_robin_load_balancing, :multiple_user_companies,
        :multiple_companies_toggle, :round_robin_on_update, :multi_dynamic_sections, :custom_dashboard],
      :inherits => [ :garden_jan_17 ]
    },

    :forest_jan_17 => {
      :features => [ :mailbox, :whitelisted_ips ],
      :inherits => [ :estate_jan_17 ]
    }

  }

  ADVANCED_FEATURES = [:link_tickets, :parent_child_tickets, :shared_ownership, :field_service_management, :assets]
  ADVANCED_FEATURES_TOGGLE = ADVANCED_FEATURES.map{|f| "#{f}_toggle".to_sym}

  # to be removed in DB to bitmap phase 3 changes.
  # Features added temporarily to avoid release for all the customers at one shot
  # Default feature when creating account has been made true :surveys & ::survey_links $^&WE^%$E
  TEMPORARY_FEATURES = {
    :bi_reports => false, :contact_merge_ui => false, :social_revamp => true, :multiple_user_emails => false,
    round_robin_revamp: false,
    :facebook_realtime => false, :autorefresh_node => false, :tokenize_emoji => false,
    :custom_dashboard => false, :updated_twilio_client => false,
    :report_field_regenerate => false, :reports_regenerate_data => false,
    :chat_enable => false, :saml_old_issuer => false, :spam_dynamo => true,
    :redis_display_id => true, :es_multilang_solutions => false,
    :sort_by_customer_response => false, :survey_links => true,
    :tags_filter_reporting => false,
    :saml_unspecified_nameid => false, :euc_hide_agent_metrics => false,
    :single_session_per_user => false, :marketplace_app => false, :sandbox_account => false,
    :collaboration => false
  }

  # to be removed in DB to bitmap phase 3 changes.
  # NOTE ::: Before adding any new features, please have a look at the TEMPORARY_FEATURES
  SELECTABLE_FEATURES = {
    :gamification_enable => false, :portal_cc => false, :personalized_email_replies => false, :agent_collision => false,
    :id_less_tickets => false, :reply_to_based_tickets => true, :freshfone => false,
    :no_list_view_count_query => false, :client_debugging => false, :collision_socket => false,
    :resource_rate_limit => false, :disable_agent_forward => false, :call_quality_metrics => false,
    :disable_rr_toggle => false, :domain_restricted_access => false, :freshfone_conference => false,
    :marketplace => false, :fa_developer => false,:archive_tickets => false, :compose_email => false,
    :limit_mobihelp_results => false, :ecommerce => false, :es_v2_writes => true, :shared_ownership => false,
    :salesforce_sync => false, :freshfone_call_metrics => false, :cobrowsing => false,
    :threading_without_user_check => false, :freshfone_call_monitoring => false, :freshfone_caller_id_masking => false,
    :agent_conference => false, :freshfone_warm_transfer => false, :restricted_helpdesk => false, :enable_multilingual => false,
    :count_es_writes => false, :count_es_reads => false, :activity_revamp => true, :countv2_writes => false, :countv2_reads => false,
    :helpdesk_restriction_toggle => false, :freshfone_acw => false, :ticket_templates => false, :cti => false, :all_notify_by_custom_server => false,
    :freshfone_custom_forwarding => false, :freshfone_onboarding => false, :freshfone_gv_forward => false, :skill_based_round_robin => false,
    :salesforce_v2 => false, :advanced_search => false, :advanced_search_bulk_actions => false, :dynamics_v2 => false, :chat => false, :chat_routing => false,
    :freshreports_analytics => false, :disable_old_reports => false, contact_custom_activity_api: false, assets: false, assets_toggle: false }

  # This list below is for customer portal features list only to prevent from adding addition features
  ADMIN_CUSTOMER_PORTAL_FEATURES =  {:anonymous_tickets => true, :open_solutions => true, :auto_suggest_solutions => true,
                            :open_forums => false, :google_signin => true, :twitter_signin => true, :facebook_signin => true,
                            :signup_link => true, :captcha => true, :prevent_ticket_creation_for_others=> true,
                            :moderate_all_posts => false, :moderate_posts_with_links => true, :hide_portal_forums => false,
                            :forum_captcha_disable => false, :public_ticket_url => false }

  MAIL_PROVIDER = { :sendgrid => 1, :mailgun => 2 }

  #Features that need to connect to the FDnode server
  FD_NODE_FEATURES = ['cti']

  TEMPORARY_AND_SELECTABLE_FEATURES_TO_BITMAP = [
    :gamification_enable, :personalized_email_replies, :agent_collision,
    :cascade_dispatchr, :cascade_dispatcher, :id_less_tickets, :reply_to_based_tickets,
    :no_list_view_count_query, :client_debugging, :collision_socket,
    :resource_rate_limit, :disable_agent_forward, :call_quality_metrics,
    :domain_restricted_access, :freshfone_conference, :marketplace, :fa_developer,
    :archive_tickets, :compose_email, :limit_mobihelp_results, :ecommerce,
    :es_v2_writes, :shared_ownership, :freshfone_call_metrics, :cobrowsing,
    :threading_without_user_check, :freshfone_call_monitoring, :collaboration,
    :freshfone_caller_id_masking, :agent_conference, :freshfone_warm_transfer,
    :restricted_helpdesk, :enable_multilingual, :countv2_writes, :countv2_reads,
    :helpdesk_restriction_toggle, :freshfone_acw, :ticket_templates, :cti,
    :all_notify_by_custom_server, :freshfone_custom_forwarding, :freshfone,
    :freshfone_onboarding, :freshfone_gv_forward, :skill_based_round_robin,
    :advanced_search, :advanced_search_bulk_actions, :chat, :chat_routing,
    :tokenize_emoji, :custom_dashboard, :report_field_regenerate,
    :saml_old_issuer, :redis_display_id, :es_multilang_solutions,
    :sort_by_customer_response, :survey_links, :tags_filter_reporting,
    :saml_unspecified_nameid, :euc_hide_agent_metrics, :single_session_per_user,
    :bi_reports, :contact_merge_ui, :multiple_user_emails, :facebook_realtime,
    :autorefresh_node, :updated_twilio_client, :count_es_reads,
    :reports_regenerate_data, :chat_enable, :sandbox_account, :portal_cc,
    :disable_rr_toggle, :count_es_writes, :round_robin_revamp, :business_hours,
    :scenario_automations, :social_revamp, :spam_dynamo, :activity_revamp
  ].to_set.freeze

  TEMPORARY_AND_SELECTABLE_FEATURES_TO_LP = (
    TEMPORARY_AND_SELECTABLE_FEATURES_TO_BITMAP
  ).each_with_object(
    SELECTABLE_FEATURES.dup.merge(TEMPORARY_FEATURES.dup)
  ) do |fname, temp_features|
    temp_features.delete(fname)
  end

  # all plan features were migrated first.
  DB_TO_BITMAP_MIGRATION_FEATURES_LIST = PLANS_AND_FEATURES.collect do |key, value|
    value[:features]
  end.flatten!.uniq!.to_set

  # Pricing plan 2019 migration changes
  [:marketplace, :fa_developer].each do |feature|
    DB_TO_BITMAP_MIGRATION_FEATURES_LIST.add(feature)
  end

  # required for phase 2 of DB to bitmap migration.
  FEATURE_NAME_CHANGES = {
    twitter: :advanced_twitter,
    facebook: :advanced_facebook,
    agent_collision: :collision,
    cascade_dispatchr: :cascade_dispatcher
  }.freeze

  DB_TO_BITMAP_MIGRATION_P2_FEATURES_LIST = (
    [
      *DB_TO_BITMAP_MIGRATION_FEATURES_LIST, # phase 1 (plan features)
      *ADMIN_CUSTOMER_PORTAL_FEATURES.keys,
      *TEMPORARY_AND_SELECTABLE_FEATURES_TO_BITMAP
    ].to_set
  ).freeze

  DB_TO_LP_MIGRATION_P2_FEATURES_LIST = (
    TEMPORARY_AND_SELECTABLE_FEATURES_TO_LP.keys.to_set -
    DB_TO_BITMAP_MIGRATION_P2_FEATURES_LIST
  ).freeze
  # DB to Bitmap/LP migration ends

  # List of Launchparty features available in code. Set it to true if it has to be enabled when signing up a new account

  LAUNCHPARTY_FEATURES = [TEMPORARY_AND_SELECTABLE_FEATURES_TO_LP].reduce(
    {
      hide_og_meta_tags: false, admin_dashboard: false, agent_conference: false, agent_dashboard: false,
      agent_new_ticket_cache: false, api_search_beta: false, autopilot_headsup: false,
      autoplay: false, bi_reports: false, cache_new_tkt_comps_forms: false,
      delayed_dispatchr_feature: false, disable_old_sso: false, enable_old_sso: false,
      es_count_reads: false, es_count_writes: false, es_down: false, es_tickets: false,
      es_v1_enabled: false, es_v2_reads: false, fb_msg_realtime: false,
      force_index_tickets: false, freshfone_call_tracker: false, freshfone_caller_id_masking: false,
      freshfone_new_notifications: false, freshfone_onboarding: false, gamification_perf: false,
      gamification_quest_perf: false, lambda_exchange: false, automation_revamp: false,
      list_page_new_cluster: false, meta_read: false, most_viewed_articles: false,
      multifile_attachments: true, new_footer_feedback_box: false, new_leaderboard: false,
      periodic_login_feature: false, restricted_helpdesk: false,
      round_robin_capping: false, sidekiq_dispatchr_feature: false,
      supervisor_dashboard: false, support_new_ticket_cache: false,
      synchronous_apps: false, ticket_list_page_filters_cache: false,
      skip_hidden_tkt_identifier: false, agent_collision_alb: false,
      auto_refresh_alb: false, countv2_template_read: false,
      customer_sentiment_ui: false, portal_solution_cache_fetch: false, activity_ui: false,
      customer_sentiment: false, countv2_template_write: false, logout_logs: false,
      froala_editor: false, es_v2_splqueries: false,
      suggest_tickets: false, :"Freshfone New Notifications" => false, feedback_widget_captcha: false,
      es_multilang_solutions: false, requester_widget: false, spam_blacklist_feature: false,
      custom_timesheet: false, antivirus_service: false, hide_api_key: false,
      skip_ticket_threading: false, multi_dynamic_sections: true, dashboard_new_alias: false,
      attachments_scope: false, kbase_spam_whitelist: false, forum_post_spam_whitelist: false,
      enable_qna: false, enable_insights: false, whitelist_supervisor_sla_limitation: false,
      escape_liquid_attributes: true, escape_liquid_for_reply: true, escape_liquid_for_portal: true,
      close_validation: false, pjax_reload: false, one_hop: false, lifecycle_report: false,
      service_writes: false, service_reads: false, disable_banners: false,
      admin_only_mint: false, send_emails_via_fd_email_service_feature: false,
      user_notifications: false, freshplug_enabled: false, dkim: false, dkim_email_service: false,
      sha1_enabled: false, disable_archive: false, sha256_enabled: false,
      auto_ticket_export: false, select_all: false, facebook_realtime: false,
      :"Freshfone Call Tracker" => false, ticket_contact_export: false,
      custom_apps: false, timesheet: false, api_jwt_auth: false, disable_emails: false,
      skip_portal_cname_chk: false, falcon_signup: false, falcon_portal_theme: false,
      image_annotation: false, email_actions: false, ner: false, disable_freshchat: false,
      freshchat_integration: false, froala_editor_forums: false, note_central_publish: false,
      ticket_central_publish: false, solutions_central_publish: false, freshid: false,
      onboarding_inlinemanual: false, incoming_attachment_limit_25: false,
      fetch_ticket_from_ref_first: false, outgoing_attachment_limit_25: false, whitelist_sso_login: false,
      imap_error_status_check: false, va_any_field_without_none: false,
      auto_complete_off: false, freshworks_omnibar: false, dependent_field_validation: false,
      post_central_publish: false, installed_app_publish: false,
      euc_migrated_twitter: false, new_ticket_recieved_metric: false,
      es_msearch: true, canned_forms: false, attachment_virus_detection: false,
      old_link_back_url_validation: false, stop_contacts_count_query: false,
      product_central_publish: false, help_widget: false, undo_send: false,
      bot_email_channel: false, bot_email_central_publish: false, archive_ticket_fields: true,
      sso_login_expiry_limitation: false, csat_email_scan_compatibility: false,
      email_deprecated_style_parsing: false, saml_ecrypted_assertion: false,
      quoted_text_parsing_feature: false, description_by_default: false,
      skip_invoice_due_warning: false,
      agent_group_central_publish: false, custom_fields_search: true,
      update_billing_info: false, allow_billing_info_update: false, tag_central_publish: false,
      archive_tickets_api: false, redis_picklist_id: true, bot_agent_response: false, fluffy: false,
      scheduling_fsm_dashboard: false, nested_field_revamp: true, service_worker: false, kbase_mint: true, freshvisual_configs: false,
      freshid_org_v2: false, hide_agent_login: false, office365_adaptive_card: false, helpdesk_tickets_by_product: false, article_es_search_by_filter: false,
      text_custom_fields_in_etl: false, email_spoof_check: false, disable_email_spoof_check: false,
      recalculate_daypass: false, prevent_wc_ticket_create: true, allow_wildcard_ticket_create: false,
      attachment_redirect_expiry: false, solutions_agent_portal: false, solutions_agent_metrics: false, fsm_admin_automations: false,
      requester_privilege: false, allow_huge_ccs: false, sso_unique_session: false, supervisor_custom_status: false, asset_management: false,
      sandbox_temporary_offset: false, downgrade_policy: true, skip_posting_to_fb: true, launch_fsm_geolocation: false,
      allow_update_agent: false, facebook_dm_outgoing_attachment: true, hide_mailbox_error_from_agents: false,
      prevent_lang_detect_for_spam: false, jira_onpremise_reporter: false, support_ticket_rate_limit: false, sidekiq_logs_to_central: false, portal_central_publish: false, encode_emoji_in_solutions: false,
      forums_agent_portal: false, mailbox_google_oauth: false, migrate_euc_pages_to_us: false, agent_collision_revamp: false, topic_editor_with_html: false,
      mailbox_forward_setup: false, remove_image_attachment_meta_data: false, ticket_field_revamp: true, new_timeline_view: false, email_mailbox: true, facebook_admin_ui_revamp: false,
      detect_lang_from_email_service: false, sla_policy_revamp: false, freshdesk_freshsales_bundle: false,
      fsm_for_garden_plan: true, fsm_for_blossom_plan: true, requester_widget_timeline: false, enable_secure_login_check: false, enable_twitter_requester_fields: true, marketplace_gallery: false,
      facebook_public_api: false, twitter_public_api: false, retry_emails: false, fb_message_echo_support: false, portal_prototype_update: false, solutions_quick_view: false, solutions_freshconnect: false,
      fsm_scheduler_month_view: false, facebook_post_outgoing_attachment: true, solutions_dashboard: false, freshid_sso_sync: false, fw_sso_admin_security: false, article_versioning_redis_lock: false, handle_custom_fields_conflicts: false, shopify_api_revamp: false,
      omni_chat_agent: false, emberize_agent_form: false, emberize_agent_list: false, portal_frameworks_update: false, ticket_filters_central_publish: false
    }, :merge
  )

  BLOCK_GRACE_PERIOD = 90.days

  ACCOUNT_TYPES = {
    :production_without_sandbox => 0,
    :production_with_sandbox => 1,
    :sandbox => 2
  }

  PARENT_CHILD_INFRA_FEATURES = [:parent_child_tickets, :field_service_management]
  CONTACT_DATA = [:first_name, :last_name, :email, :phone].freeze
  FILE_DOWNLOAD_URL_EXPIRY_TIME = 60.to_i.seconds
end
