class Account < ActiveRecord::Base

  DEFAULT_IN_OPERATOR_FIELDS = {
    :ticket =>   ["priority", "ticket_type", "status", "source", "product_id", "responder_id", "group_id"] ,
    :requester => ["time_zone", "language"],
    :company => ["name"]
  }

  RESERVED_DOMAINS = %W(  blog help chat smtp mail www ftp imap pop faq docs doc team people india us talk
                          upload download info lounge community forums ticket tickets tour about pricing bugs in out
                          logs projects itil marketing partner store channel reseller resellers online
                          contact admin #{AppConfig['admin_subdomain']} girish shan vijay parsu kiran shihab
                          productdemo resources static static0 static1 static2 static3 static4 static5
                          static6 static7 static8 static9 static10 dev apps freshapps fone
                          elb elb1 elb2 elb3 elb4 elb5 elb6 elb7 elb8 elb9 elb10 attachment euattachment eucattachment agent-hermes) + FreshopsSubdomains

  PLANS_AND_FEATURES = {
    :basic => { :features => [ :twitter, :custom_domain, :multiple_emails ] },

    :pro => {
      :features => [ :gamification, :scenario_automations, :customer_slas, :business_hours, :forums,
        :surveys, :scoreboard, :facebook, :timesheets, :css_customization, :advanced_reporting ],
      :inherits => [ :basic ]
    },

    :premium => {
      :features => [ :multi_product, :multi_timezone , :multi_language, :enterprise_reporting, :dynamic_content],
      :inherits => [ :pro ] #To make the hierarchy easier
    },

    :sprout => {
      :features => [ :scenario_automations, :business_hours ]
    },

    :blossom => {
      :features => [ :gamification, :auto_refresh, :twitter, :facebook, :forums, :surveys , :scoreboard, :timesheets,
        :custom_domain, :multiple_emails, :advanced_reporting, :default_survey, :sitemap, :requester_widget],
      :inherits => [ :sprout ]
    },

    :garden => {
      :features => [ :multi_product, :customer_slas, :multi_timezone , :multi_language,
        :css_customization, :advanced_reporting, :multiple_business_hours, :dynamic_content, :chat,
        :ticket_templates, :custom_survey ],
      :inherits => [ :blossom ]
    },

    :estate => {
      :features => [ :collision, :layout_customization, :round_robin, :enterprise_reporting,
        :custom_ssl, :custom_roles, :multiple_business_hours, :facebook_page_tab, :chat_routing, :dynamic_sections,
        :helpdesk_restriction_toggle, :round_robin_load_balancing, :multiple_user_companies,
        :multiple_companies_toggle, :round_robin_on_update, :multi_dynamic_sections ],
      :inherits => [ :garden ]
    },

    :forest => {
      :features => [ :mailbox, :whitelisted_ips ],
      :inherits => [ :estate ]
    },

    :sprout_classic => {
      :features => [ :scenario_automations, :business_hours, :custom_domain, :multiple_emails ]
    },

    :blossom_classic => {
      :features => [ :gamification, :auto_refresh, :twitter, :facebook, :forums, :surveys,
        :scoreboard, :timesheets, :advanced_reporting ],
      :inherits => [ :sprout_classic ]
    },

    :garden_classic => {
      :features => [ :multi_product, :customer_slas, :multi_timezone , :multi_language,
        :css_customization, :advanced_reporting, :dynamic_content, :ticket_templates ],
      :inherits => [ :blossom_classic ]
    },

    :estate_classic => {
      :features => [ :collision, :layout_customization, :round_robin, :enterprise_reporting,
        :custom_ssl, :custom_roles, :multiple_business_hours, :facebook_page_tab, :chat_routing, :dynamic_sections,
        :helpdesk_restriction_toggle, :round_robin_load_balancing, :multiple_user_companies,
        :multiple_companies_toggle, :round_robin_on_update, :multi_dynamic_sections ],
      :inherits => [ :garden_classic ]
    },

    :sprout_jan_17 => {
      :features => [ :scenario_automations, :business_hours ]
    },

    :blossom_jan_17 => {
      :features => [ :gamification, :auto_refresh, :twitter, :facebook, :surveys , :scoreboard, :timesheets,
        :custom_domain, :multiple_emails, :advanced_reporting, :default_survey, :sitemap, :requester_widget ],
      :inherits => [ :sprout_jan_17 ]
    },

    :garden_jan_17 => {
      :features => [ :forums, :multi_language, :css_customization, :advanced_reporting, :dynamic_content, :chat,
        :ticket_templates, :custom_survey ],
      :inherits => [ :blossom_jan_17 ]
    },

    :estate_jan_17 => {
      :features => [ :multi_product, :customer_slas, :multi_timezone ,
        :collision, :layout_customization, :round_robin, :enterprise_reporting,
        :custom_ssl, :custom_roles, :multiple_business_hours, :facebook_page_tab, :chat_routing, :dynamic_sections,
        :helpdesk_restriction_toggle, :round_robin_load_balancing, :multiple_user_companies,
        :multiple_companies_toggle, :round_robin_on_update, :multi_dynamic_sections ],
      :inherits => [ :garden_jan_17 ]
    },

    :forest_jan_17 => {
      :features => [ :mailbox, :whitelisted_ips ],
      :inherits => [ :estate_jan_17 ]
    }

  }

  ADVANCED_FEATURES = [:link_tickets, :parent_child_tickets]
  ADVANCED_FEATURES_TOGGLE = ADVANCED_FEATURES.map{|f| "#{f}_toggle".to_sym}

  # Features added temporarily to avoid release for all the customers at one shot
  # Default feature when creating account has been made true :surveys & ::survey_links $^&WE^%$E
  TEMPORARY_FEATURES = {
    :bi_reports => false, :contact_merge_ui => false, :social_revamp => true, :multiple_user_emails => false,
    :round_robin_revamp => false, :solutions_meta_read => false,
    :facebook_realtime => false, :autorefresh_node => false, :tokenize_emoji => false,
    :custom_dashboard => false, :updated_twilio_client => false,
    :report_field_regenerate => false, :reports_regenerate_data => false,
    :chat_enable => false, :saml_old_issuer => false, :spam_dynamo => true,
    :redis_display_id => false, :es_multilang_solutions => false,
    :sort_by_customer_response => false, :survey_links => true,
    :tags_filter_reporting => false,
    :saml_unspecified_nameid => false, :euc_hide_agent_metrics => false,
    :single_session_per_user => false, :marketplace_app => false, :sandbox_account => false,
    :collaboration => false
  }


  # NOTE ::: Before adding any new features, please have a look at the TEMPORARY_FEATURES
  SELECTABLE_FEATURES = {
    :gamification_enable => false, :portal_cc => false, :personalized_email_replies => false, :agent_collision => false,
    :cascade_dispatchr => false, :id_less_tickets => false, :reply_to_based_tickets => true, :freshfone => false,
    :no_list_view_count_query => false, :client_debugging => false, :collision_socket => false,
    :resource_rate_limit => false, :disable_agent_forward => false, :call_quality_metrics => false,
    :disable_rr_toggle => false, :domain_restricted_access => false, :freshfone_conference => false,
    :marketplace => true, :fa_developer => true,:archive_tickets => false, :compose_email => false,
    :limit_mobihelp_results => false, :ecommerce => false, :es_v2_writes => true, :shared_ownership => false,
    :salesforce_sync => false, :freshfone_call_metrics => false, :cobrowsing => false,
    :threading_without_user_check => false, :freshfone_call_monitoring => false, :freshfone_caller_id_masking => false,
    :agent_conference => false, :freshfone_warm_transfer => false, :restricted_helpdesk => false, :enable_multilingual => false,
    :count_es_writes => false, :count_es_reads => false, :activity_revamp => true, :countv2_writes => false, :countv2_reads => false,
    :helpdesk_restriction_toggle => false, :freshfone_acw => false, :ticket_templates => false, :cti => false, :all_notify_by_custom_server => false,
    :freshfone_custom_forwarding => false, :freshfone_onboarding => false, :freshfone_gv_forward => false, :skill_based_round_robin => false,
    :salesforce_v2 => false, :advanced_search => false, :advanced_search_bulk_actions => false,:dynamics_v2 => false }

  # This list below is for customer portal features list only to prevent from adding addition features
  ADMIN_CUSTOMER_PORTAL_FEATURES =  {:anonymous_tickets => true, :open_solutions => true, :auto_suggest_solutions => true,
                            :open_forums => true, :google_signin => true, :twitter_signin => true, :facebook_signin => true,
                            :signup_link => true, :captcha => false,
                            :moderate_all_posts => false, :moderate_posts_with_links => true, :hide_portal_forums => false,
                            :forum_captcha_disable => false, :public_ticket_url => false }

  MAIL_PROVIDER = { :sendgrid => 1, :mailgun => 2 }

  #Features that need to connect to the FDnode server
  FD_NODE_FEATURES = ['cti']

  # List of Launchparty features available in code. Set it to true if it has to be enabled when signing up a new account
  LAUNCHPARTY_FEATURES = {
    :activity_ui_disable => false, :admin_dashboard => false, :agent_conference => false, :agent_dashboard => false,
    :agent_new_ticket_cache => false, :api_search_beta => false, :autopilot_headsup => false, :autoplay => false,
    :bi_reports => false, :cache_new_tkt_comps_forms => false, :delayed_dispatchr_feature => false,
    :disable_old_sso => false, :enable_old_sso => false, :es_count_reads => false, :es_count_writes => false,
    :es_down => false, :es_tickets => false, :es_v1_enabled => false, :es_v2_reads => false, :fb_msg_realtime => false,
    :force_index_tickets => false, :freshfone_call_tracker => false, :freshfone_caller_id_masking => false,
    :freshfone_new_notifications => false, :freshfone_onboarding => false, :gamification_perf => false,
    :gamification_quest_perf => false, :lambda_exchange => false, :link_tickets => false,
    :list_page_new_cluster => false, :meta_read => false, :most_viewed_articles => false,
    :multifile_attachments => true, :new_footer_feedback_box => false, :new_leaderboard => false,
    :parent_child_tickets => false, :periodic_login_feature => false, :restricted_helpdesk => false,
    :round_robin_capping => false, :sidekiq_dispatchr_feature => false,
    :solutions_meta_read => false, :supervisor_dashboard => false, :support_new_ticket_cache => false,
    :synchronous_apps => false, :ticket_list_page_filters_cache => false, :translate_solutions => false,
    :spam_detection_service => false, :skip_hidden_tkt_identifier => false, :agent_collision_alb => false, :auto_refresh_alb => false,
    :countv2_template_read => false, :customer_sentiment_ui => false, :portal_solution_cache_fetch => false, :activity_ui => false,
    :customer_sentiment => false, :countv2_template_write => false, :logout_logs => false, :gnip_2_0 => false, :froala_editor => false,
    :es_v2_splqueries => false, :suggest_tickets => false, :"Freshfone New Notifications" => false, :feedback_widget_captcha => false,
    :es_multilang_solutions => false, :requester_widget => false, :spam_blacklist_feature => false,
    :custom_timesheet => false, :antivirus_service => false, :hide_api_key => false, :new_sla_logic => false,
    :dashboard_new_alias => false, :attachments_scope => false, :kbase_spam_whitelist => false, :forum_post_spam_whitelist => false, :email_failures => false,
    :falcon => false
  }

end
