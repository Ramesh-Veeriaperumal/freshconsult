 ActionController::Routing::Routes.draw do |map|

  map.connect '/images/helpdesk/attachments/:id/:style.:format', :controller => '/helpdesk/attachments', :action => 'show', :conditions => { :method => :get }

  map.connect "/javascripts/:action.:format", :controller => 'javascripts'

  # Routing for Asset management Jammit
  Jammit::Routes.draw(map)

  map.resources :authorizations
  map.google_sync '/google_sync', :controller=> 'authorizations', :action => 'sync'
  map.callback '/auth/google_login/callback', :controller => 'google_login', :action => 'create_account_from_google'
  map.callback '/auth/google_gadget/callback', :controller => 'google_login', :action => 'create_account_from_google'
  map.callback '/auth/:provider/callback', :controller => 'authorizations', :action => 'create'
  map.calender '/oauth2callback', :controller => 'authorizations', :action => 'create', :provider => 'google_oauth2'
  map.failure '/auth/failure', :controller => 'authorizations', :action => 'failure'

  map.resources :solutions_uploaded_images, :controller => 'solutions_uploaded_images', :only => [ :index, :create ]

  map.resources :forums_uploaded_images, :controller => 'forums_uploaded_images', :only => :create

  map.resources :tickets_uploaded_images, :controller => 'tickets_uploaded_images', :only => :create

  map.resources :contact_import , :collection => {:csv => :get, :google => :get}

  map.resources :customers ,:member => {:quick => :post, :sla_policies => :get } do |customer|
     customer.resources :time_sheets, :controller=>'helpdesk/time_sheets'
   end
  map.connect '/customers/filter/:state/*letter', :controller => 'customers', :action => 'index'
  
  map.resources :companies ,:member => {:quick => :post, :sla_policies => :get } do |customer|
    customer.resources :time_sheets, :controller=>'helpdesk/time_sheets'
  end
  map.connect '/companies/filter/:state/*letter', :controller => 'companies', :action => 'index'

  map.resources :contacts, :collection => { :contact_email => :get, :autocomplete => :get } , 
    :member => { :hover_card => :get, :hover_card_in_new_tab => :get, :quick_contact_with_company => :post, 
      :restore => :put, :make_agent =>:put, :make_occasional_agent => :put, :create_contact => :post, 
      :update_contact => :put, :update_bg_and_tags => :put} do |contacts|
    contacts.resources :contact_merge, :collection => { :search => :get }
  end
  map.connect '/contacts/filter/:state/*letter', :controller => 'contacts', :action => 'index'

  map.resources :groups

  map.resources :profiles , :member => { :change_password => :post }, :collection => {:reset_api_key => :post, :notification_read => :put} do |profiles|
    profiles.resources :user_emails, :member => { :make_primary => :get, :send_verification => :put }
  end
  
  map.resources :agents, :member => { :toggle_shortcuts => :put,
                                      :restore => :put,
                                      :convert_to_user => :get,
                                      :reset_password=> :put },
                          :collection => { :create_multiple_items => :put,
                                           :info_for_node => :get} do |agent|
      agent.resources :time_sheets, :controller=>'helpdesk/time_sheets'
  end

  map.connect '/agents/filter/:state/*letter', :controller => 'agents', :action => 'index'

#  map.mobile '/mob', :controller => 'home', :action => 'mobile_index'
#  map.mobile '/mob_site', :controller => 'user_sessions', :action => 'mob_site'
  #map.resources :support_plans

  map.logout '/logout', :controller => 'user_sessions', :action => 'destroy'
  map.gauth '/oauth/googlegadget', :controller => 'user_sessions', :action => 'oauth_google_gadget'
  map.gauth '/opensocial/google', :controller => 'user_sessions', :action => 'opensocial_google'
  map.gauth_done '/authdone/google', :controller => 'user_sessions', :action => 'google_auth_completed'
  map.login '/login', :controller => 'user_sessions', :action => 'new'
  map.sso_login '/login/sso', :controller => 'user_sessions', :action => 'sso_login'
  map.saml_login '/login/saml', :controller => 'user_sessions', :action => 'saml_login'
  map.login_normal '/login/normal', :controller => 'user_sessions', :action => 'new'
  map.signup_complete '/signup_complete/:token', :controller => 'user_sessions', :action => 'signup_complete'

  map.openid_done '/google/complete', :controller => 'accounts', :action => 'openid_complete'

  map.zendesk_import '/zendesk/import', :controller => 'admin/zen_import', :action => 'index'

  map.tauth '/twitter/authdone', :controller => 'social/twitter_handles', :action => 'authdone'
  
  map.download_file '/download_file/:source/:token', :controller => 'admin/data_export', :action => 'download'
  #map.register '/register', :controller => 'users', :action => 'create'
  #map.signup '/signup', :controller => 'users', :action => 'new'

  map.namespace :freshfone do |freshfone|
    freshfone.resources :ivrs, :member => { :activate => :post, :deactivate => :post }
    freshfone.resources :call, :collection => {:status => :post, :in_call => :post, :direct_dial_success => :post, :inspect_call => :get, :caller_data => :get, :call_transfer_success => :post }
    freshfone.resources :queue, :collection => {:enqueue => :post, :dequeue => :post, :quit_queue_on_voicemail => :post, :trigger_voicemail => :post, :trigger_non_availability => :post, :bridge => :post, :hangup => :post}
    freshfone.resources :voicemail, :collection => {:quit_voicemail => :post}
    freshfone.resources :call_transfer, :collection => {:initiate => :post, :transfer_incoming_call => :post, :transfer_outgoing_call => :post, :available_agents => :get }
    freshfone.resources :device, :collection => { :record => :post, :recorded_greeting => :get }
    freshfone.resources :call_history, :collection => { :custom_search => :get,
                                                       :children => :get, :recent_calls => :get }
    freshfone.resources :blacklist_number, :collection => { :create => :post, :destroy => :post }
    freshfone.resources :users,:collection => { :presence => :post, :get_presence => :get, :node_presence => :post, :availability_on_phone => :post,
                           :refresh_token => :post, :in_call => :post, :reset_presence_on_reconnect => :post }
    freshfone.resources :autocomplete, :collection => { :requester_search => :get, :customer_phone_number => :get }
    freshfone.resources :usage_triggers, :collection => { :notify => :post }
    freshfone.resources :ops_notification, :member => { :voice_notification => :post }
  end

  map.resources :freshfone, :collection => { :voice => :get, :build_ticket => :post,
                                  :dashboard_stats => :get, :get_available_agents => :get,
                                  :credit_balance => :get, :ivr_flow => :get, :preview_ivr => :get
                                }

  map.resources :users, :member => { :delete_avatar => :delete,
          :block => :put, :assume_identity => :get, :profile_image => :get }, :collection => {:revert_identity => :get, :me => :get}
  map.resource :user_session
  map.register '/register/:activation_code', :controller => 'activations', :action => 'new'
  map.register_new_email 'register_new_email/:activation_code', :controller => 'activations', :action => 'new_email'
  map.activate '/activate/:perishable_token', :controller => 'activations', :action => 'create'
  map.resources :activations, :member => { :send_invite => :put }
  map.resources :home, :only => :index
  map.resources :ticket_fields, :only => :index
  map.resources :email, :only => [:new, :create]
  map.resources :mailgun, :only => :create
  map.resources :password_resets, :except => [:index, :show, :destroy]
  map.resources :sso, :collection => {:login => :get, :facebook => :get, :google_login => :get}
  map.resource :account_configuration

  map.namespace :integrations do |integration|
    integration.resources :installed_applications, :member =>{:install => :put, :uninstall => :get}
    integration.resources :applications, :member=>{:custom_widget_preview => :post}
    integration.resources :integrated_resource, :member =>{:create => :put, :delete => :delete}
    integration.resources :google_accounts, :member =>{:edit => :get, :delete => :delete, :update => :put, :import_contacts => :put}
    integration.resources :gmail_gadgets, :collection =>{:spec => :get}
    integration.resources :jira_issue, :collection => {:get_issue_types => :get, :unlink => :put, :notify => :post, :register => :get}
    integration.resources :pivotal_tracker, :collection => { :tickets => :get, :pivotal_updates => :post, :update_config => :post}
    integration.resources :user_credentials
    integration.resources :logmein, :collection => {:rescue_session => :get, :update_pincode => :put, :refresh_session => :get, :tech_console => :get, :authcode => :get}
    integration.oauth_action '/refresh_access_token/:app_name', :controller => 'oauth_util', :action => 'get_access_token'
    integration.custom_install 'oauth_install/:provider', :controller => 'applications', :action => 'oauth_install'
    integration.oauth 'install/:app', :controller => 'oauth', :action => 'authenticate'
  end

  map.namespace :admin do |admin|
    admin.resources :home, :only => :index
    admin.resources :day_passes, :only => [:index, :update], :member => { :buy_now => :put, :toggle_auto_recharge => :put }
    admin.resources :widget_config, :only => :index
    admin.resources :contact_fields, :only => :index
    admin.resources :chat_widgets
    admin.resources :automations, :member => { :clone_rule => :get },:collection => { :reorder => :put }
    admin.resources :va_rules, :member => { :activate_deactivate => :put, :clone_rule => :get }, :collection => { :reorder => :put }
    admin.resources :supervisor_rules, :member => { :activate_deactivate => :put, :clone_rule => :get },
      :collection => { :reorder => :put }
    admin.resources :observer_rules, :member => { :activate_deactivate => :put, :clone_rule => :get },
      :collection => { :reorder => :put }
    admin.resources :email_configs, :member => { :make_primary => :put, :deliver_verification => :get, :test_email => :put} , 
    :collection => { :existing_email => :get, 
                     :personalized_email_enable => :post, 
                     :personalized_email_disable => :post, 
                     :reply_to_email_enable => :post, 
                     :reply_to_email_disable => :post
                    }
    admin.register_email '/register_email/:activation_code', :controller => 'email_configs', :action => 'register_email'
    admin.resources :email_notifications
    admin.edit_notification '/email_notifications/:type/:id/edit', :controller => 'email_notifications', :action => 'edit'
    admin.resources :getting_started, :collection => {:rebrand => :put}
    admin.resources :business_calendars
    admin.resources :security, :member => { :update => :put }, :collection => { :request_custom_ssl => :post }
    admin.resources :data_export, :collection => {:export => :any }
    admin.resources :portal, :only => [ :index, :update ]
    admin.namespace :canned_responses do |ca_response|
      ca_response.resources :folders do |folder|
        folder.resources :responses, :collection => { :delete_multiple => :delete, :update_folder => :put }, :member=> { :delete_shared_attachments => :any  }
      end
    end
    admin.resources :products, :member => { :delete_logo => :delete, :delete_favicon => :delete }
    admin.resources :portal, :only => [ :index, :update] do |portal|
      portal.resource :template,
                      :collection => { :show =>:get, :update => :put, :soft_reset => :put,
                                        :restore_default => :get, :publish => :get, :clear_preview => :get } do |template|
        template.resources :pages, :member => { :edit_by_page_type => :get, :soft_reset => :put }
      end
    end
    admin.resources :surveys, :collection => { :enable => :post, :disable => :post }
    admin.resources :gamification, :collection => { :toggle => :post, :quests => :get, :update_game => :put }
    admin.resources :quests, :member => { :toggle => :put }
    admin.resources :zen_import, :collection => {:import_data => :post, :status => :get }
    admin.resources :email_commands_setting, :member => { :update => :put }
    admin.resources :account_additional_settings, :member => { :update => :put, :assign_bcc_email => :get}
    admin.resources :freshfone, :only => [:index], :collection => { :search => :get, :toggle_freshfone => :put }
    admin.namespace :freshfone do |freshfone|
      freshfone.resources :numbers, :collection => { :purchase => :post }
      freshfone.resources :credits, :collection => { :disable_auto_recharge => :put, :enable_auto_recharge => :put, :purchase => :post }
    end
    admin.resources :roles    
    admin.namespace :social do |social|
      social.resources :streams, :controller => 'streams', :only => :index
      social.resources :twitter_streams, :controller => 'twitter_streams'
      social.resources :twitters, :controller => 'twitter_handles', :collection => {:authdone => :any}
    end
    admin.resources :mailboxes
    admin.namespace :mobihelp do |mobihelp|
      mobihelp.resources :apps
    end
  end

  map.namespace :search do |search|
    search.resources :home, :only => :index, :collection => { :suggest => :get }
    search.resources :autocomplete, :collection => { :requesters => :get , :agents => :get, :companies => :get, :tags => :get }
    search.resources :tickets, :only => :index
    search.resources :solutions, :only => :index
    search.resources :forums, :only => :index
    search.resources :customers, :only => :index
    search.ticket_related_solutions '/related_solutions/ticket/:ticket/', :controller => 'solutions', :action => 'related_solutions'
    search.ticket_search_solutions '/search_solutions/ticket/:ticket/', :controller => 'solutions', :action => 'search_solutions'
  end
  map.connect '/search/tickets/filter/:search_field', :controller => 'search/tickets', :action => 'index'
  map.connect '/search/all', :controller => 'search/home', :action => 'index'
  map.connect '/search/merge_topic', :controller => 'search/merge_topic', :action => 'index'
  map.connect '/search/topics.:format', :controller => 'search/forums', :action => 'index'
  map.connect '/mobile/tickets/get_suggested_solutions/:ticket.:format', :controller => 'search/solutions', :action => 'related_solutions'

  map.namespace :reports do |report|
    report.resources :helpdesk_glance_reports, :controller => 'helpdesk_glance_reports',
      :collection => {:generate => :post,:generate_pdf => :post,:send_report_email => :post,
      :fetch_activity_ajax => :post,:fetch_metrics=> :post}
    report.resources :analysis_reports, :controller => 'helpdesk_load_analysis',
      :collection => {:generate => :post,:generate_pdf => :post,:send_report_email => :post}
    report.resources :performance_analysis_reports, :controller => 'helpdesk_performance_analysis',
      :collection => {:generate => :post,:generate_pdf => :post,:send_report_email => :post}
    report.resources :agent_glance_reports, :controller => 'agent_glance_reports',
      :collection => {:generate => :post,:generate_pdf => :post,:send_report_email => :post,
      :fetch_activity_ajax => :post,:fetch_metrics=> :post}
    report.resources :group_glance_reports, :controller => 'group_glance_reports',
      :collection => {:generate => :post,:generate_pdf => :post,:send_report_email => :post,
      :fetch_activity_ajax => :post,:fetch_metrics=> :post}
    report.resources :agent_analysis_reports, :controller => 'agents_analysis',
      :collection => {:generate => :post,:generate_pdf => :post,:send_report_email => :post,
      :fetch_chart_data => :post}
    report.resources :group_analysis_reports, :controller => 'groups_analysis',
      :collection => {:generate => :post,:generate_pdf => :post,:send_report_email => :post,
      :fetch_chart_data => :post}
    report.resources :agents_comparison_reports, :controller => 'agents_comparison',
      :collection => {:generate => :post,:generate_pdf => :post,:send_report_email => :post}
    report.resources :groups_comparison_reports, :controller => 'groups_comparison',
      :collection => {:generate => :post,:generate_pdf => :post,:send_report_email => :post}
    report.resources :customer_glance_reports, :controller => 'customer_glance_reports',
      :collection => {:generate => :post,:generate_pdf => :post,:send_report_email => :post,
      :fetch_activity_ajax => :post,:fetch_metrics=> :post}
    report.resources :customers_analysis_reports, :controller => 'customers_analysis',
      :collection => {:generate => :post,:generate_pdf => :post,:send_report_email => :post,
      :fetch_chart_data => :post}
    report.resources :report_filters, :controller => 'report_filters',
      :collection => {:create => :post,:destroy => :post}
    report.namespace :freshfone do |freshfone|
      freshfone.resources :summary_reports, :controller => 'summary_reports', 
      :collection => {:generate => :post, :export_csv => :post } 
    end
  end

  map.resources :reports
  map.resources :timesheet_reports , :controller => 'reports/timesheet_reports' , :collection => {:report_filter => :post , :export_csv => :post, :generate_pdf => :post}
  map.customer_activity   '/activity_reports/customer', :controller => 'reports/customer_reports', :action => 'index'
  map.helpdesk_activity   '/activity_reports/helpdesk', :controller => 'reports/helpdesk_reports', :action => 'index'
  map.customer_activity_generate   '/activity_reports/customer/generate', :controller => 'reports/customer_reports', :action => 'generate'
  map.helpdesk_activity_generate   '/activity_reports/helpdesk/generate', :controller => 'reports/helpdesk_reports', :action => 'generate'
  map.helpdesk_activity_export   '/activity_reports/helpdesk/export_to_excel', :controller => 'reports/helpdesk_reports', :action => 'export_to_excel'
  map.scoreboard_activity '/gamification/reports', :controller => 'reports/gamification_reports', :action => 'index'
  map.survey_activity '/survey/reports', :controller => 'reports/survey_reports', :action => 'index'
  map.survey_back_to_list '/survey/reports/:category/:view', :controller => 'reports/survey_reports', :action => 'index'
  map.survey_list '/survey/reports_list', :controller => 'reports/survey_reports', :action => 'list'
  map.survey_detail_report '/survey/report_details/:entity_id/:category', :controller => 'reports/survey_reports', :action => 'report_details'
  map.survey_overall_report '/survey/overall_report/:category', :controller => 'reports/survey_reports', :action => 'report_details'
  map.survey_feedbacks '/reports/survey_reports/feedbacks', :controller => 'reports/survey_reports', :action => 'feedbacks'
  map.survey_refresh_details '/reports/survey_reports/refresh_details', :controller => 'reports/survey_reports', :action => 'refresh_details'


  map.namespace :social do |social|
    social.resources :twitters, :controller => 'twitter_handles',
                :collection =>  { :show => :any, :feed => :any, :create_twicket => :post, :send_tweet => :any, :signin => :any, :tweet_exists => :get , :user_following => :any, :authdone => :any , :twitter_search => :get},
                :member     =>  { :search => :any, :edit => :any }

    social.resources :gnip, :controller => 'gnip_twitter',
                :collection => {:reconnect => :post}
                
    social.resources :streams, 
                :collection => { :stream_feeds => :get, :show_old => :get, :fetch_new => :get, :interactions => :any }
    
    social.resources :welcome, :controller => 'welcome',
                :only => :index, :collection => { :get_stats => :get, :enable_feature => :post }
                
    social.resources :twitter,
                :collection => {  :twitter_search => :get, :show_old => :get, :fetch_new => :get, :create_fd_item => :post,
                                  :user_info => :get, :retweets => :get, :reply => :post, :retweet => :get, :post_tweet => :post,
                                  :favorite => :post, :unfavorite => :post, :followers => :get, :follow => :post, :unfollow => :post}
  end

  #SAAS copy starts here
  map.with_options(:conditions => {:subdomain => AppConfig['admin_subdomain']}) do |subdom|
    subdom.root :controller => 'subscription_admin/subscriptions', :action => 'index'
    subdom.with_options(:namespace => 'subscription_admin/', :name_prefix => 'admin_', :path_prefix => nil) do |admin|
      admin.resources :subscriptions, :collection => {:customers => :get, :deleted_customers => :get, :customers_csv => :get}
      admin.resources :accounts,:member => {:add_day_passes => :post}, :collection => {:agents => :get, :tickets => :get, :renewal_csv => :get }
      admin.resources :subscription_plans, :as => 'plans'
      # admin.resources :subscription_discounts, :as => 'discounts'
      admin.resources :subscription_affiliates, :as => 'affiliates', :collection => { :add_affiliate_transaction => :post },
                                                :member => { :add_subscription => :post }
      admin.resources :subscription_payments, :as => 'payments'
      admin.resources :subscription_announcements, :as => 'announcements'
      admin.resources :conversion_metrics, :as => 'metrics'
      admin.resources :account_tools, :as => 'tools', :collection =>{:regenerate_reports_data => :post, :update_global_blacklist_ips => :put }
      admin.resources :manage_users, :as => 'manage_users', :collection =>{:add_whitelisted_user_id => :post, :remove_whitelisted_user_id => :post }
      admin.namespace :resque do |resque|
        resque.home '', :controller => 'home', :action => 'index'
        resque.failed_show '/failed/:queue_name/show', :controller => 'failed', :action => 'show'
        resque.resources :failed, :member => { :destroy => :delete , :requeue => :put }, :collection => { :destroy_all => :delete, :requeue_all => :put }
      end
      
      admin.freshfone '/freshfone_admin', :controller => :freshfone_subscriptions, :action => :index
      admin.freshfone_stats '/freshfone_admin/stats', :controller => :freshfone_stats, :action => :index
      admin.freshfone_actions '/freshfone_admin/actions', :controller => :freshfone_actions, :action => :index
      
      # admin.resources :analytics
      admin.resources :spam_watch, :only => :index
      admin.spam_details ':shard_name/spam_watch/:user_id/:type', :controller => :spam_watch, :action => :spam_details
      admin.spam_user ':shard_name/spam_user/:user_id', :controller => :spam_watch, :action => :spam_user
      admin.block_user ':shard_name/block_user/:user_id', :controller => :spam_watch, :action => :block_user
      admin.hard_block_user ':shard_name/hard_block/:user_id', :controller => :spam_watch, :action => :hard_block
      admin.internal_whitelist ':shard_name/internal_whitelist/:user_id', :controller => :spam_watch, :action => :internal_whitelist
      admin.resources :subscription_events, :as => 'events', :collection => { :export_to_csv => :get }
      admin.resources :custom_ssl, :as => 'customssl', :collection => { :enable_custom_ssl => :post }
      admin.resources :currencies, :as => 'currency'
      admin.subscription_logout 'admin_sessions/logout', :controller => :admin_sessions , :action => :destroy
      admin.subscription_login 'admin_sessions/login', :controller => :admin_sessions , :action => :new
      admin.resources :subscription_users, :as => 'subscription_users', :member => { :update => :post, :edit => :get, :show => :get }, :collection => {:reset_password => :get }
    end
  end

  map.with_options(:conditions => {:subdomain => AppConfig['partner_subdomain']}) do |subdom|
    subdom.with_options(:namespace => 'partner_admin/', :name_prefix => 'partner_', :path_prefix => nil) do |partner|
      partner.resources :affiliates, :collection => {:add_affiliate_transaction => :post}
    end
  end

  map.with_options(:conditions => { :subdomain => AppConfig['billing_subdomain'] }) do |subdom|
    subdom.with_options(:namespace => 'billing/', :path_prefix => nil) do |billing|
      billing.resources :billing, :collection => { :trigger => :post }
    end
  end

  map.namespace :widgets do |widgets|
    widgets.resource :feedback_widget, :member => { :loading => :get }
  end

  map.plans '/signup', :controller => 'accounts', :action => 'plans'
  map.connect '/signup/d/:discount', :controller => 'accounts', :action => 'plans'
  map.thanks '/signup/thanks', :controller => 'accounts', :action => 'thanks'
  map.create '/signup/create/:discount', :controller => 'accounts', :action => 'create', :discount => nil
  map.resource :account, :collection => {:rebrand => :put, :dashboard => :get, :thanks => :get,
    :cancel => :any, :canceled => :get , :signup_google => :any, :delete_logo => :delete, :delete_favicon => :delete }
  map.resource :subscription, :collection => { :plans => :get, :billing => :any, :plan => :any, :calculate_amount => :any, :convert_subscription_to_free => :put }

  map.new_account '/signup/:plan/:discount', :controller => 'accounts', :action => 'new', :plan => nil, :discount => nil

  map.forgot_password '/account/forgot', :controller => 'user_sessions', :action => 'forgot'
  map.reset_password '/account/reset/:token', :controller => 'user_sessions', :action => 'reset'

  map.search_domain '/search_user_domain', :controller => 'domain_search', :action => 'locate_domain'

  #SAAS copy ends here


  # Restful-authentication routes. Not to be included in final engine.  map.resource :session

  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller

  # Sample resource route with more complex sub-resources
  #   map.resources :products do |products|
  #     products.resources :comments
  #     products.resources :sales, :collection => { :recent => :get }
  #   end

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  # map.root :controller => "welcome"

  # See how all your routes lay out with "rake routes"

  # Begin routes to be included in final engine

  # The reason for the strange name_prefix values is that when you pass a Helpdesk::Ticket
  # instance to url_for, it will look for the named path called "helpdesk_ticket". So if
  # you pass in [@ticket, @note] it will look for helpdesk_ticket_helpdesk_note, etc.
  map.namespace :helpdesk do |helpdesk|

    helpdesk.resources :tags, :collection => { :autocomplete => :get, :remove_tag => :delete, :rename_tags => :put, :merge_tags => :put }

#    helpdesk.resources :issues, :collection => {:empty_trash => :delete}, :member => { :delete_all => :delete, :assign => :put, :restore => :put, :restore_all => :put } do |ticket|
#      ticket.resources :notes, :member => { :restore => :put }, :name_prefix => 'helpdesk_issue_helpdesk_'
#    end

    helpdesk.resources :tickets, :collection => { :user_tickets => :get, :empty_trash => :delete, :empty_spam => :delete,
                                    :delete_forever => :delete, :user_ticket => :get, :search_tweets => :any, :custom_search => :get,
                                    :export_csv => :post, :latest_ticket_count => :post, :add_requester => :post,
                                    :filter_options => :get, :full_paginate => :get, :summary => :get,
                                    :update_multiple_tickets => :get, :configure_export => :get, :custom_view_save => :get },
                                 :member => { :reply_to_conv => :get, :forward_conv => :get, :view_ticket => :get,
                                    :assign => :put, :restore => :put, :spam => :put, :unspam => :put, :close => :post,
                                    :execute_scenario => :post, :close_multiple => :put, :pick_tickets => :put,
                                    :change_due_by => :put, :split_the_ticket =>:post, :status => :get,
                                    :merge_with_this_request => :post, :print => :any, :latest_note => :get,  :activities => :get,
                                    :clear_draft => :delete, :save_draft => :post, :update_ticket_properties => :put } do |ticket|


      ticket.resources :surveys, :collection =>{:results=>:get, :rate=>:post}
      ticket.resources :conversations, :collection => {:reply => :post, :forward => :post, :note => :post,
                                       :twitter => :post, :facebook => :post, :mobihelp => :post, :full_text => :get}

      ticket.resources :notes, :member => { :restore => :put }, :collection => {:since => :get, :agents_autocomplete => :get}, :name_prefix => 'helpdesk_ticket_helpdesk_'
      ticket.resources :subscriptions, :collection => { :create_watchers => :post,
                                                        :unsubscribe => :get,
                                                        :unwatch => :delete,
                                                        :unwatch_multiple => :delete },
                                       :name_prefix => 'helpdesk_ticket_helpdesk_'
      ticket.resources :tag_uses, :name_prefix => 'helpdesk_ticket_helpdesk_'
      ticket.resources :reminders, :name_prefix => 'helpdesk_ticket_helpdesk_'
      ticket.resources :time_sheets, :name_prefix => 'helpdesk_ticket_helpdesk_'
      ticket.resources :mobihelp_ticket_extras, :name_prefix => 'helpdesk_ticket_helpdesk_', :only => :index

    end

    #helpdesk.resources :ticket_issues

    helpdesk.resources :leaderboard, :collection => { :mini_list => :get, :agents => :get,
      :groups => :get }, :only => [ :mini_list, :agents, :groups ]
    helpdesk.resources :quests, :only => [ :active, :index, :unachieved ],
      :collection => { :active => :get, :unachieved => :get }


    helpdesk.resources :notes
    helpdesk.resources :bulk_ticket_actions , :collection => {:update_multiple => :put }
    helpdesk.resources :merge_tickets, :collection => { :complete_merge => :post, :merge => :put }
    helpdesk.resources :ca_folders
    helpdesk.resources :canned_responses, :collection => {:search => :get, :recent => :get}
    helpdesk.resources :reminders, :member => { :complete => :put, :restore => :put }
    helpdesk.resources :time_sheets, :member => { :toggle_timer => :put}

    helpdesk.filter_tag_tickets    '/tags/:id/*filters', :controller => 'tags', :action => 'show'
    helpdesk.filter_tickets        '/tickets/filter/tags', :controller => 'tags', :action => 'index'
    helpdesk.filter_view_default   '/tickets/filter/:filter_name', :controller => 'tickets', :action => 'index'
    helpdesk.filter_view_custom    '/tickets/view/:filter_key', :controller => 'tickets', :action => 'index'
    helpdesk.requester_filter      '/tickets/filter/requester/:requester_id', :controller => 'tickets', :action => 'index'
    helpdesk.customer_filter       '/tickets/filter/customer/:customer_id', :controller => 'tickets', :action => 'index'
    helpdesk.company_filter       '/tickets/filter/company/:company_id', :controller => 'tickets', :action => 'index'
    helpdesk.tag_filter            '/tickets/filter/tags/:tag_id', :controller => 'tickets', :action => 'index'
    helpdesk.reports_filter        '/tickets/filter/reports/:report_type', :controller => 'tickets', :action => 'index'


    #helpdesk.filter_issues '/issues/filter/*filters', :controller => 'issues', :action => 'index'

    helpdesk.formatted_dashboard '/dashboard.:format', :controller => 'dashboard', :action => 'index'
    helpdesk.dashboard '', :controller => 'dashboard', :action => 'index'
    helpdesk.sales_manager 'sales_manager', :controller => 'dashboard', :action => 'sales_manager'
    helpdesk.agent_status 'agent-status', :controller => 'dashboard', :action => 'agent_status'
    helpdesk.visitor '/freshchat/visitor/:filter', :controller => 'visitor', :action => 'index'
    helpdesk.chat_archive '/freshchat/chat/:filter', :controller => 'visitor', :action => 'index'

#   helpdesk.resources :dashboard, :collection => {:index => :get, :tickets_count => :get}

    helpdesk.resources :articles, :collection => { :autocomplete => :get }

    helpdesk.resources :attachments, :member => { :unlink_shared => :delete, :text_content => :get }
    helpdesk.with_options :path_prefix => "facebook/helpdesk" do |fb_helpdesk|
      fb_helpdesk.resources :attachments, :only => [:show, :destroy]
    end

    helpdesk.resources :cloud_files

    helpdesk.resources :authorizations, :collection => { :autocomplete => :get, :agent_autocomplete => :get,
                                                        :company_autocomplete => :get }

    helpdesk.resources :autocomplete, :collection => { :requester => :get, :company => :get }
    
    helpdesk.resources :sla_policies, :collection => {:reorder => :put}, :member => {:activate => :put},
                      :except => :show

    helpdesk.resources :commons

  end

  map.resources :api_webhooks, :as => 'webhooks/subscription'
  
  map.namespace :solution do |solution|
    solution.resources :categories, :collection => {:reorder => :put}  do |category|
      category.resources :folders, :collection => {:reorder => :put}  do |folder|
        folder.resources :articles, :member => { :thumbs_up => :put, :thumbs_down => :put , :delete_tag => :post }, :collection => {:reorder => :put} do |article|
          article.resources :tag_uses
        end
      end
    end
    solution.resources :articles, :only => :show
  end

  # Savage Beast route config entries starts from here
  map.resources :posts, :name_prefix => 'all_', :collection => { :search => :get }
  map.resources :topics, :posts, :monitorship

  map.namespace :discussions do |discussion|
    discussion.resources :forums, :collection => {:reorder => :put}, :except => :index
    discussion.resources :topics,
        :except => :index,
        :member => { :toggle_lock => :put, :latest_reply => :get, :update_stamp => :put,:remove_stamp => :put, :vote => :put, :destroy_vote => :delete, :reply => :get },
        :collection => {:destroy_multiple => :delete } do |topic|
      discussion.topic_page "/topics/:id/page/:page", :controller => :topics, :action => :show
      discussion.topic_component "/topics/:id/component/:name", :controller => :topics, :action => :component

      topic.resources :posts, :except => :new, :member => { :toggle_answer => :put }
      topic.best_answer "/answer/:id", :controller => :posts, :action => :best_answer

    end
    discussion.resources :moderation,
      :collection => { :empty_folder => :delete, :spam_multiple => :put },
      :member => { :approve => :put, :ban => :put, :mark_as_spam => :put }

    discussion.moderation_filter '/moderation/filter/:filter', :controller => 'moderation', :action => 'index'
    discussion.resources :merge_topic, :collection => { :select => :post, :review => :put, :confirm => :post, :merge => :put }
  end

  map.connect '/discussions/categories.:format', :controller => 'discussions', :action => 'create', :conditions => { :method => :post }
  map.connect '/discussions/categories.:format', :controller => 'discussions', :action => 'categories', :conditions => { :method => :get } 
  map.connect '/discussions/categories/:id.:format', :controller => 'discussions', :action => 'show',  :conditions => { :method => :get }
  map.connect '/discussions/categories/:id.:format', :controller => 'discussions', :action => 'destroy', :conditions => { :method => :delete }
  map.connect '/discussions/categories/:id.:format', :controller => 'discussions', :action => 'update', :conditions => { :method => :put }

  map.resources :discussions, :collection => { :your_topics => :get, :sidebar => :get, :categories => :get, :reorder => :put }

  map.resources :discussions

  %w(forum).each do |attr|
    map.resources :posts, :name_prefix => "#{attr}_", :path_prefix => "/#{attr.pluralize}/:#{attr}_id"
  end

  map.resources :categories, :collection => {:reorder => :put}, :controller=>'forum_categories'  do |forum_c|
  forum_c.resources :forums, :collection => {:reorder => :put} do |forum|
    forum.resources :topics, :member => { :users_voted => :get, :update_stamp => :put,:remove_stamp => :put, :update_lock => :put }, :collection => { :destroy_multiple => :delete }
    forum.resources :topics do |topic|
      topic.resources :posts, :member => { :toggle_answer => :put }
      topic.best_answer "/answer/:id", :controller => :posts, :action => :best_answer
      end
    end
  end


  map.view_monitorship 'discussions/:object/:id/subscriptions/is_following.:format', :controller => 'monitorships', :action => 'is_following', :conditions => {:method => :get}
  map.toggle_monitorship 'discussions/:object/:id/subscriptions/:type.:format', :controller => 'monitorships', :action => 'toggle'
  # Savage Beast route config entries ends from here

  # Theme for the support portal
  map.connect "/support/theme.:format", :controller => 'theme/support', :action => :index
  map.connect "/support/theme_rtl.:format", :controller => 'theme/support_rtl', :action => :index  
  map.connect "/helpdesk/theme.:format", :controller => 'theme/helpdesk', :action => :index

  # Support Portal routes
  map.namespace :support do |support|
    # Portal home
    support.home 'home', :controller => "home"

    # Portal preview
    support.preview 'preview', :controller => "preview"

    # Login for users in the portal
    support.resource :login, :controller => "login", :only => [:new, :create]
    support.connect "/login", :controller => 'login', :action => :new

    # Signup for a new user in the portal
    # registrations route is not renamed to signup
    support.resource :signup, :only => [:new, :create]
    support.connect "/signup", :controller => 'signups', :action => :new

    # Signed in user profile edit and update routes
    support.resource :profile, :only => [:edit, :update]

    # Search for the portal, can search Articles, Topics and Tickets
    support.resource :search, :controller => 'search', :only => :show,
      :member => { :solutions => :get, :topics => :get, :tickets => :get, :suggest_topic => :get }
    support.resource :search do |search|
      search.connect "/topics/suggest", :controller => :search, :action => :suggest_topic
      search.connect "/articles/:article_id/related_articles", :controller => :search, :action => :related_articles
    end

    # Forums for the portal, the items will be name spaced by discussions
    support.resources :discussions, :only => [:index, :show],:collection =>{:user_monitored=>:get}
    support.namespace :discussions do |discussion|
      discussion.resources :forums, :only => :show, :member => { :toggle_monitor => :put}
      discussion.filter_topics "/forums/:id/:filter_topics_by", :controller => :forums,
        :action => :show
      discussion.connect "/forums/:id/page/:page", :controller => :forums,
        :action => :show
      discussion.resources :topics, :except => :index, :member => { :like => :put, :hit => :get,
          :unlike => :put, :toggle_monitor => :put,:monitor => :put, :check_monitor => :get, :users_voted => :get, :toggle_solution => :put, :reply => :get },
          :collection => {:my_topics => :get} do |topic|
        discussion.connect "/topics/my_topics/page/:page", :controller => :topics,
          :action => :my_topics
        discussion.connect "/topics/:id/page/:page", :controller => :topics,
          :action => :show
        topic.resources :posts, :except => [:index, :new, :show],
          :member => { :toggle_answer => :put }
        topic.best_answer "/answer/:id", :controller => :posts, :action => :best_answer
      end
    end

    # Solutions for the portal
    support.resources :solutions, :only => [:index, :show]
    support.namespace :solutions do |solution|
      solution.connect "/folders/:id/page/:page", :controller => :folders,
        :action => :show
      solution.resources :folders, :only => :show
      solution.resources :articles, :only => :show, :member => { :thumbs_up => :put,
        :thumbs_down => :put , :create_ticket => :post, :hit => :get }
    end

    # !PORTALCSS TODO The below is a access routes for accessing routes without the solutions namespace
    # Check with shan if we really need this route or the one with the solution namespace
    support.resources :articles, :controller => 'solutions/articles',
      :member => { :thumbs_up => :put, :thumbs_down => :put , :create_ticket => :post }

    # Tickets for the portal
    # All portal tickets including company_tickets are now served from this controller
    support.resources :tickets,
      :collection => { :check_email => :get, :configure_export => :get, :filter => :get, :export_csv => :post },
      :member => { :close => :post, :add_people => :put } do |ticket|

      ticket.resources :notes, :name_prefix => 'support_ticket_helpdesk_'
    end

    support.portal_survey '/surveys/:ticket_id', :controller => 'surveys', :action => 'create_for_portal'
    support.customer_survey '/surveys/:survey_code/:rating/new', :controller => 'surveys', :action => 'new'
    support.survey_feedback '/surveys/:survey_code/:rating', :controller => 'surveys', :action => 'create',
      :conditions => { :method => :post }

    support.namespace :mobihelp do |mobihelp|
      mobihelp.resources :tickets
      mobihelp.connect "/tickets/:id/notes.:format", :controller => 'tickets' , :action => 'add_note'
      mobihelp.connect "/tickets/:id/close.:format", :controller => 'tickets' , :action => 'close'
    end

  end

  map.namespace :anonymous do |anonymous|
    anonymous.resources :requests
  end

  map.namespace :public do |p|
     p.resources :tickets do |ticket|
        ticket.resources :notes
    end
  end

  map.namespace :mobile do |mobile|
    mobile.resources :tickets, :collection =>{:view_list => :get, :get_portal => :get, :ticket_properties => :get , :load_reply_emails => :get}
    mobile.resources :automations, :only =>:index
	mobile.resources :notifications, :collection => {:register_mobile_notification => :put}, :only => {}
    mobile.resources :settings,  :only =>:index, :collection => {:mobile_pre_loader => :get, :deliver_activation_instructions => :get}
    mobile.resources :freshfone, :collection => {:numbers => :get}
  end
 
  map.namespace :mobihelp do |mobihelp|
    mobihelp.resources :devices, { :collection => {:register => :post, :app_config => :get, :register_user => :post }}
    mobihelp.resources :solutions, { :collection => {:articles => :get }}
  end

  map.resources :rabbit_mq, :only => [ :index ]

  map.route '/marketplace/login', :controller => 'google_login', :action => 'marketplace_login'
  map.route '/openid/google', :controller => 'google_login', :action => 'marketplace_login'
  map.route '/gadget/login', :controller => 'google_login', :action => 'google_gadget_login'
  map.route '/google/login', :controller => 'google_login', :action => 'portal_login'

  map.root :controller => "home"
  #map.connect '', :controller => 'helpdesk/dashboard', :action => 'index'

  # End routes to be included in final engine

  # Install the default routes as the lowest priority.
  # Note: These default routes make all actions in every controller accessible via GET requests. You should
  # consider removing the them or commenting them out if you're using named routes and resources.
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'

  map.connect '/freshchat/create_ticket', :controller => 'chats', :action => 'create_ticket', :method => :post
  map.connect '/freshchat/add_note', :controller => 'chats', :action => 'add_note', :method => :post
  map.connect '/freshchat/chat_note', :controller => 'chats', :action => 'chat_note', :method => :post


  map.connect '/freshchat/activate', :controller => 'chats', :action => 'activate', :method => :post

  map.connect '/freshchat/site_toggle', :controller => 'chats', :action => 'site_toggle', :method => :post

  map.connect '/freshchat/widget_toggle', :controller => 'chats', :action => 'widget_toggle', :method => :post
  map.connect '/freshchat/widget_activate', :controller => 'chats', :action => 'widget_activate', :method => :post

  map.connect '/freshchat/agents', :controller => 'chats', :action => 'agents', :method => :get

end
