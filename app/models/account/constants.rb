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
                          ipaas-app ipaas-ui analytics-export mars-us mars-euc mars-au mars-ind) + FreshopsSubdomains + PartnerSubdomains

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
        :multiple_companies_toggle, :round_robin_on_update],
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
        :multiple_companies_toggle, :round_robin_on_update],
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
        :multiple_companies_toggle, :round_robin_on_update, :custom_dashboard],
      :inherits => [ :garden_jan_17 ]
    },

    :forest_jan_17 => {
      :features => [ :mailbox, :whitelisted_ips ],
      :inherits => [ :estate_jan_17 ]
    }

  }

  ADVANCED_FEATURES = [:link_tickets, :parent_child_tickets, :shared_ownership, :field_service_management, :assets]
  ADVANCED_FEATURES_TOGGLE = ADVANCED_FEATURES.map{|f| "#{f}_toggle".to_sym}

  # Features added temporarily to avoid release for all the customers at one shot
  # Default feature when creating account has been made true :surveys & ::survey_links $^&WE^%$E
  TEMPORARY_FEATURES = {
    :bi_reports => false, :custom_dashboard => false, :updated_twilio_client => false,
    :report_field_regenerate => false,
    :chat_enable => false, :saml_old_issuer => false,
    :redis_display_id => true, :es_multilang_solutions => false,
    :sort_by_customer_response => false, :survey_links => true,
    :saml_unspecified_nameid => false, :euc_hide_agent_metrics => false,
    :single_session_per_user => false, :marketplace_app => false,
    :collaboration => false
  }

  # NOTE ::: Before adding any new features, please have a look at the TEMPORARY_FEATURES
  SELECTABLE_FEATURES = {
    :gamification_enable => false, :personalized_email_replies => false,
    :id_less_tickets => false, :reply_to_based_tickets => true, :freshfone => false,
    :client_debugging => false, :collision_socket => false,
    :disable_agent_forward => false, :call_quality_metrics => false,
    :disable_rr_toggle => false, :domain_restricted_access => false, :freshfone_conference => false,
    :marketplace => false, :archive_tickets => false, :compose_email => false,
    :ecommerce => false, :es_v2_writes => true, :shared_ownership => false,
    :freshfone_call_metrics => false, :cobrowsing => false,
    :threading_without_user_check => false, :freshfone_call_monitoring => false, :freshfone_caller_id_masking => false,
    :agent_conference => false, :freshfone_warm_transfer => false, :restricted_helpdesk => false, :enable_multilingual => false,
    :activity_revamp => true, :helpdesk_restriction_toggle => false, :freshfone_acw => false, :ticket_templates => false, :cti => false, :all_notify_by_custom_server => false,
    :freshfone_custom_forwarding => false, :freshfone_onboarding => false, :freshfone_gv_forward => false, :skill_based_round_robin => false,
    :advanced_search => false, :advanced_search_bulk_actions => false, :chat => false, :chat_routing => false,
    :freshreports_analytics => false, :disable_old_reports => false, contact_custom_activity_api: false, assets: false, assets_toggle: false }

  # This list below is for customer portal features list only to prevent from adding addition features
  ADMIN_CUSTOMER_PORTAL_FEATURES = {
    :google_signin => true, :twitter_signin => true, :facebook_signin => true,
    :captcha => true, :prevent_ticket_creation_for_others => true, :hide_portal_forums => false
  }

  ADMIN_CUSTOMER_PORTAL_SETTINGS = [
    :signup_link, :anonymous_tickets, :auto_suggest_solutions,
    :public_ticket_url, :open_solutions, :open_forums,
    :forum_captcha_disable, :moderate_posts_with_links, :moderate_all_posts,
    :helpdesk_tickets_by_product, :solutions_agent_metrics
  ].freeze

  MAIL_PROVIDER = { :sendgrid => 1, :mailgun => 2 }

  #Features that need to connect to the FDnode server
  FD_NODE_FEATURES = ['cti']

  FEATURE_NAME_CHANGES = {
    twitter: :advanced_twitter,
    facebook: :advanced_facebook,
    cascade_dispatchr: :cascade_dispatcher
  }.freeze

  DB_TO_LP_FEATURES = Set[:salesforce_sync, :salesforce_v2, :marketplace_app]

  # List of Launchparty features available in code. Set it to true if it has to be enabled when signing up a new account

  LAUNCHPARTY_FEATURES = {

    hide_og_meta_tags: false, agent_conference: false, api_search_beta: false, autoplay: false, bi_reports: false,
    disable_old_sso: false, enable_old_sso: false, es_count_writes: false, feature_based_settings: false,
    es_down: false, es_tickets: false, es_v1_enabled: false, es_v2_reads: false, fb_msg_realtime: false,
    force_index_tickets: false, freshfone_caller_id_masking: false,
    freshfone_onboarding: false, gamification_perf: false,
    gamification_quest_perf: false, lambda_exchange: false, automation_revamp: false,
    meta_read: false, most_viewed_articles: false,
    new_footer_feedback_box: false, periodic_login_feature: false, restricted_helpdesk: false,
    support_new_ticket_cache: false, synchronous_apps: false, skip_hidden_tkt_identifier: false,
    customer_sentiment_ui: false, portal_solution_cache_fetch: false,
    customer_sentiment: false, logout_logs: false,
    es_v2_splqueries: false, suggest_tickets: false,
    feedback_widget_captcha: false, es_multilang_solutions: false,
    spam_blacklist_feature: false, antivirus_service: false, hide_api_key: false,
    skip_ticket_threading: false,
    kbase_spam_whitelist: false,
    whitelist_supervisor_sla_limitation: false,
    service_writes: false, service_reads: false,
    admin_only_mint: false, send_emails_via_fd_email_service_feature: false, user_notifications: false,
    freshplug_enabled: false, dkim: false, dkim_email_service: false, sha1_enabled: false, disable_archive: false,
    sha256_enabled: false, auto_ticket_export: false,
    ticket_contact_export: false,
    api_jwt_auth: false, disable_emails: false, skip_portal_cname_chk: false,
    falcon_portal_theme: false, image_annotation: false, email_actions: false, ner: false, disable_freshchat: false,
    freshid: false,
    incoming_attachment_limit_25: false, fetch_ticket_from_ref_first: false, outgoing_attachment_limit_25: false,
    whitelist_sso_login: false, va_any_field_without_none: false,
    auto_complete_off: false, freshworks_omnibar: false,
    new_ticket_recieved_metric: false, es_msearch: true,
    canned_forms: false, attachment_virus_detection: false, old_link_back_url_validation: false,
    stop_contacts_count_query: false,
    bot_email_channel: false, archive_ticket_fields: true,
    sso_login_expiry_limitation: false, csat_email_scan_compatibility: false, email_deprecated_style_parsing: false,
    saml_ecrypted_assertion: false, quoted_text_parsing_feature: false, description_by_default: false,
    skip_invoice_due_warning: false, custom_fields_search: true, update_billing_info: false, allow_billing_info_update: false,
    archive_tickets_api: false, bot_agent_response: false, fluffy: false, nested_field_revamp: true,
    freshid_org_v2: false, hide_agent_login: false, ticket_source_revamp: false,
    article_es_search_by_filter: false,
    text_custom_fields_in_etl: false, email_spoof_check: false, disable_email_spoof_check: false,
    recalculate_daypass: false, allow_wildcard_ticket_create: false,
    attachment_redirect_expiry: false,
    requester_privilege: false, allow_huge_ccs: false, sso_unique_session: false,
    asset_management: false, sandbox_temporary_offset: false, downgrade_policy: true,
    launch_fsm_geolocation: false, geolocation_historic_popup: false, allow_update_agent: false,
    hide_mailbox_error_from_agents: false,
    jira_onpremise_reporter: false, sidekiq_logs_to_central: false,
    encode_emoji_in_solutions: false,
    mailbox_google_oauth: false, migrate_euc_pages_to_us: false, agent_collision_revamp: false,
    topic_editor_with_html: false, remove_image_attachment_meta_data: false,
    ticket_field_revamp: true, new_timeline_view: false,
    requester_widget_timeline: false, sprout_trial_onboarding: false,
    enable_secure_login_check: false,
    marketplace_gallery: false, facebook_public_api: false, twitter_public_api: false,
    fb_message_echo_support: false, portal_prototype_update: false,
    solutions_dashboard: false, article_versioning_redis_lock: false,
    salesforce_sync: false, salesforce_v2: false, marketplace_app: false, freshid_sso_sync: true,
    fw_sso_admin_security: false,
    omni_chat_agent: false, emberize_agent_form: false, emberize_agent_list: false, portal_frameworks_update: false,
    ticket_filters_central_publish: false, auto_refresh_revamp: false, omni_plans_migration_banner: false, kbase_omni_bundle: false,
    twitter_api_compliance: false, omni_agent_availability_dashboard: false, explore_omnichannel_feature: false, hide_omnichannel_toggle: false,
    chargebee_omni_upgrade: false, csp_reports: false, show_omnichannel_nudges: false, whatsapp_ticket_source: false, cx_feedback: false,
    export_ignore_primary_key: false, archive_ticket_central_publish: false, mailbox_ms365_oauth: false, pre_compute_ticket_central_payload: false,
    channel_command_reply_to_sidekiq: false, portal_new_settings: false
  }.freeze

  BLOCK_GRACE_PERIOD = 90.days

  ACCOUNT_TYPES = {
    :production_without_sandbox => 0,
    :production_with_sandbox => 1,
    :sandbox => 2
  }

  PARENT_CHILD_INFRA_FEATURES = [:parent_child_tickets, :field_service_management]
  CONTACT_DATA = [:first_name, :last_name, :email, :phone].freeze
  FILE_DOWNLOAD_URL_EXPIRY_TIME = 60.to_i.seconds

  # Add launchparty name to CENTRAL_PUBLISH_LAUNCHPARTY_FEATURES if the feature needs to sent to central
  # Setting feature to false, will not trigger separate account_update event on launching a key on signup
  # feature_name: true/false
  # true -> should fire separate account_update event when feature is added
  # false -> will not fire separate account_update event
  # the false/true value is not honoured if the key is launched after the account signup
  CENTRAL_PUBLISH_LAUNCHPARTY_FEATURES = {
    agent_statuses: false,
    forward_to_phone: false
  }.freeze
end
