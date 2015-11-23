class Account < ActiveRecord::Base

  RESERVED_DOMAINS = %W(  blog help chat smtp mail www ftp imap pop faq docs doc team people india us talk
                          upload download info lounge community forums ticket tickets tour about pricing bugs in out
                          logs projects itil marketing partner store channel reseller resellers online
                          contact admin #{AppConfig['admin_subdomain']} girish shan vijay parsu kiran shihab
                          productdemo resources static static0 static1 static2 static3 static4 static5
                          static6 static7 static8 static9 static10 dev apps freshapps fone
                          elb elb1 elb2 elb3 elb4 elb5 elb6 elb7 elb8 elb9 elb10 )

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
        :custom_domain, :multiple_emails, :advanced_reporting],
      :inherits => [ :sprout ]
    },
    
    :garden => {
      :features => [ :multi_product, :customer_slas, :multi_timezone , :multi_language, 
        :css_customization, :advanced_reporting, :multiple_business_hours, :dynamic_content, :chat ],
      :inherits => [ :blossom ]
    },

    :estate => {
      :features => [ :collision, :layout_customization, :round_robin, :enterprise_reporting,
        :custom_ssl, :custom_roles, :multiple_business_hours, :facebook_page_tab, :chat_routing, :dynamic_sections ],
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
      :features => [ :gamification, :auto_refresh, :twitter, :facebook, :forums, :surveys , :scoreboard, :timesheets, :advanced_reporting ],
      :inherits => [ :sprout_classic ]
    },
    
    :garden_classic => {
      :features => [ :multi_product, :customer_slas, :multi_timezone , :multi_language, 
        :css_customization, :advanced_reporting, :dynamic_content ],
      :inherits => [ :blossom_classic ]
    },

    :estate_classic => {
      :features => [ :collision, :layout_customization, :round_robin, :enterprise_reporting,
        :custom_ssl, :custom_roles, :multiple_business_hours, :facebook_page_tab, :chat_routing ],
      :inherits => [ :garden_classic ]
    }

  }

  # Default feature when creating account has been made true :surveys & ::survey_links $^&WE^%$E
    
  SELECTABLE_FEATURES = {:open_forums => true, :open_solutions => true, :auto_suggest_solutions => true,
    :anonymous_tickets =>true, :survey_links => true, :custom_survey => false, :gamification_enable => true, :google_signin => true,
    :twitter_signin => true, :facebook_signin => true, :signup_link => true, :captcha => false , :portal_cc => false, 
    :personalized_email_replies => false, :cascade_dispatchr => false,
    :id_less_tickets => false, :reply_to_based_tickets => true, :freshfone => false,
    :agent_collision => false, :multiple_user_emails => true, :facebook_realtime => true, :social_revamp => false,
    :moderate_all_posts => false, :moderate_posts_with_links => true, :redis_display_id => false, 
    :hide_portal_forums => false, :reports_regenerate_data => false, :updated_twilio_client => false, :chat_enable => false,
    :report_field_regenerate => false, :sort_by_customer_response => false, :no_list_view_count_query => false,
    :round_robin_revamp =>  false, :contact_merge_ui => true, :client_debugging => false, :collision_socket => false,
    :spam_dynamo => true , :saml_old_issuer => false, :forum_captcha_disable => false, :autorefresh_node => false, 
    :resource_rate_limit => false, :disable_agent_forward => false, :bi_reports => true, :es_multilang_solutions => false,
    :disable_rr_toggle => false, :domain_restricted_access => false, :freshfone_conference => false,
    :public_ticket_url => false, :marketplace => false, :fa_developer => false,:archive_tickets => false, :compose_email => false,
    :limit_mobihelp_results => false, :ecommerce => false, :tokenize_emoji => false, :es_v2_writes => false, 
    :salesforce_sync => false, :round_robin_on_update => false }


  # This list below is for customer portal features list only to prevent from adding addition features
  ADMIN_CUSTOMER_PORTAL_FEATURES =  [:anonymous_tickets, :open_solutions, :auto_suggest_solutions, 
                            :open_forums, :google_signin, :twitter_signin, :facebook_signin,
                            :signup_link, :captcha,
                            :moderate_all_posts, :moderate_posts_with_links, :hide_portal_forums,
                            :forum_captcha_disable, :public_ticket_url ]
end
