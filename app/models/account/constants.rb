class Account < ActiveRecord::Base

  RESERVED_DOMAINS = %W(  blog help chat smtp mail www ftp imap pop faq docs doc wiki team people india us talk
                          upload download info lounge community forums ticket tickets tour about pricing bugs in out
                          logs projects itil marketing partner store channel reseller resellers online
                          contact admin #{AppConfig['admin_subdomain']} girish shan vijay parsu kiran shihab
                          productdemo resources static static0 static1 static2 static3 static4 static5
                          static6 static7 static8 static9 static10 marketplace developer dev apps freshapps fone )

	PLANS_AND_FEATURES = {
    :basic => { :features => [ :twitter, :custom_domain, :multiple_emails ] },
    
    :pro => {
      :features => [ :scenario_automations, :customer_slas, :business_hours, :forums, 
        :surveys, :scoreboard, :facebook, :facebook_realtime, :timesheets, :css_customization, :advanced_reporting ],
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
      :features => [ :twitter, :facebook, :facebook_realtime, :forums, :surveys , :scoreboard, :timesheets, 
        :custom_domain, :multiple_emails, :advanced_reporting],
      :inherits => [ :sprout ]
    },
    
    :garden => {
      :features => [ :multi_product, :customer_slas, :multi_timezone , :multi_language, 
        :css_customization, :advanced_reporting, :multiple_business_hours, :dynamic_content ],
      :inherits => [ :blossom ]
    },

    :estate => {
      :features => [ :gamification, :agent_collision, :layout_customization, :round_robin, :enterprise_reporting,
        :custom_ssl, :custom_roles, :multiple_business_hours, :facebook_page_tab ],
      :inherits => [ :garden ]
    },

    :sprout_classic => {
      :features => [ :scenario_automations, :business_hours, :custom_domain, :multiple_emails ]
    },
    
    :blossom_classic => {
      :features => [ :twitter, :facebook, :facebook_realtime, :forums, :surveys , :scoreboard, :timesheets, :advanced_reporting ],
      :inherits => [ :sprout_classic ]
    },
    
    :garden_classic => {
      :features => [ :multi_product, :customer_slas, :multi_timezone , :multi_language, 
        :css_customization, :advanced_reporting, :dynamic_content ],
      :inherits => [ :blossom_classic ]
    },

    :estate_classic => {
      :features => [ :gamification, :agent_collision, :layout_customization, :round_robin, :enterprise_reporting,
        :custom_ssl, :custom_roles, :multiple_business_hours, :facebook_page_tab ],
      :inherits => [ :garden_classic ]
    }

  }

  # Default feature when creating account has been made true :surveys & ::survey_links $^&WE^%$E
    
  SELECTABLE_FEATURES = {:open_forums => true, :open_solutions => true, :auto_suggest_solutions => true,
    :anonymous_tickets =>true, :survey_links => true, :gamification_enable => true, :google_signin => true,
    :twitter_signin => true, :facebook_signin => true, :signup_link => true, :captcha => false , :portal_cc => false, 
    :personalized_email_replies => false, :auto_refresh => false, :chat => false, :cascade_dispatchr => false,
    :whitelisted_ips => false, :id_less_tickets => false, :reply_to_based_tickets => true, :freshfone => false }

end