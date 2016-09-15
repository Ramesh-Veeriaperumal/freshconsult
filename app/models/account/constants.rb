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
                          elb elb1 elb2 elb3 elb4 elb5 elb6 elb7 elb8 elb9 elb10 ) + FreshopsSubdomains

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
        :custom_domain, :multiple_emails, :advanced_reporting ],
      :inherits => [ :sprout ]
    },
    
    :garden => {
      :features => [ :multi_product, :customer_slas, :multi_timezone , :multi_language, 
        :css_customization, :advanced_reporting, :multiple_business_hours, :dynamic_content, :chat, :ticket_templates ],
      :inherits => [ :blossom ]
    },

    :estate => {
      :features => [ :collision, :layout_customization, :round_robin, :enterprise_reporting,
        :custom_ssl, :custom_roles, :multiple_business_hours, :facebook_page_tab, :chat_routing, :dynamic_sections, :helpdesk_restriction_toggle],
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
        :custom_ssl, :custom_roles, :multiple_business_hours, :facebook_page_tab, :chat_routing, :helpdesk_restriction_toggle ],
      :inherits => [ :garden_classic ]
    }

  }

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
    :sort_by_customer_response => false, :survey_links => true, :default_survey => false, :custom_survey => false,
    :saml_unspecified_nameid => false, :multiple_user_companies => false,
    :euc_hide_agent_metrics => false, :single_session_per_user => false
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
    :salesforce_sync => false, :round_robin_on_update => false, :freshfone_call_metrics => false, :cobrowsing => false,
    :threading_without_user_check => false, :freshfone_call_monitoring => false, :freshfone_caller_id_masking => false,
    :agent_conference => false, :freshfone_warm_transfer => false, :restricted_helpdesk => false, :enable_multilingual => false,
    :count_es_writes => false, :count_es_reads => false, :activity_revamp => false, :countv2_writes => false, :countv2_reads => false,
    :helpdesk_restriction_toggle => false, :freshfone_acw => false, :ticket_templates => false, :cti => false, :all_notify_by_custom_server => false }

  # This list below is for customer portal features list only to prevent from adding addition features
  ADMIN_CUSTOMER_PORTAL_FEATURES =  {:anonymous_tickets => true, :open_solutions => true, :auto_suggest_solutions => true, 
                            :open_forums => true, :google_signin => true, :twitter_signin => true, :facebook_signin => true,
                            :signup_link => true, :captcha => false,
                            :moderate_all_posts => false, :moderate_posts_with_links => true, :hide_portal_forums => false,
                            :forum_captcha_disable => false, :public_ticket_url => false } 

  MAIL_PROVIDER = { :sendgrid => 1, :mailgun => 2 }

  #Features that need to connect to the FDnode server
  FD_NODE_FEATURES = ['cti']

end
