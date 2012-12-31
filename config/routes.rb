 ActionController::Routing::Routes.draw do |map|

  map.connect '/images/helpdesk/attachments/:id/:style.:format', :controller => '/helpdesk/attachments', :action => 'show', :conditions => { :method => :get }
  
  map.connect "/javascripts/:action.:format", :controller => 'javascripts'
  
  # Routing for Asset management Jammit
  Jammit::Routes.draw(map)
  
  map.resources :authorizations
  map.google_sync '/google_sync', :controller=> 'authorizations', :action => 'sync'
  map.callback '/auth/:provider/callback', :controller => 'authorizations', :action => 'create'
  map.failure '/auth/failure', :controller => 'authorizations', :action => 'failure'
  
  map.resources :uploaded_images, :controller => 'uploaded_images'
  
  map.resources :contact_import , :collection => {:csv => :get, :google => :get}

  map.resources :customers ,:member => {:quick => :post} do |customer|
     customer.resources :time_sheets, :controller=>'helpdesk/time_sheets'
   end
  map.connect '/customers/filter/:state/*letter', :controller => 'customers', :action => 'index'
 
  map.resources :contacts, :collection => { :contact_email => :get, :autocomplete => :get } , :member => { :hover_card => :get, :restore => :put, :quick_customer => :post, :make_agent =>:put}
  map.connect '/contacts/filter/:state/*letter', :controller => 'contacts', :action => 'index'
  
  map.resources :groups
  
  map.resources :profiles , :member => { :change_password => :post }, :collection => {:reset_api_key => :post}
  
  map.resources :agents, :member => { :delete_avatar => :delete , :restore => :put, :convert_to_user => :get, :reset_password=> :put }, :collection => {:create_multiple_items => :put} do |agent|
      agent.resources :time_sheets, :controller=>'helpdesk/time_sheets'
  end

  map.connect '/agents/filter/:state' ,:controller => 'agents' ,:action => 'index'
  map.resources :sla_details
  
#  map.mobile '/mob', :controller => 'home', :action => 'mobile_index'
#  map.mobile '/mob_site', :controller => 'user_sessions', :action => 'mob_site'
  #map.resources :support_plans

  map.resources :sl_as

  map.logout '/logout', :controller => 'user_sessions', :action => 'destroy'
  map.gauth '/openid/google', :controller => 'user_sessions', :action => 'openid_google'
  map.gauth '/opensocial/google', :controller => 'user_sessions', :action => 'opensocial_google'
  map.gauth_done '/authdone/google', :controller => 'user_sessions', :action => 'google_auth_completed'
  map.login '/login', :controller => 'user_sessions', :action => 'new'  
  map.sso_login '/login/sso', :controller => 'user_sessions', :action => 'sso_login'
  map.login_normal '/login/normal', :controller => 'user_sessions', :action => 'new'
  map.signup_complete '/signup_complete/:token', :controller => 'user_sessions', :action => 'signup_complete'

  map.openid_done '/google/complete', :controller => 'accounts', :action => 'openid_complete'
  
  map.zendesk_import '/zendesk/import', :controller => 'admin/zen_import', :action => 'index'
  
  map.tauth '/twitter/authdone', :controller => 'social/twitter_handles', :action => 'authdone'
  
  #map.register '/register', :controller => 'users', :action => 'create'
  #map.signup '/signup', :controller => 'users', :action => 'new'
  map.resources :users, :member => { :delete_avatar => :delete, :change_account_admin => :put,:block => :put, :assume_identity => :get},
                        :collection => {:revert_identity => :get}
  map.resource :user_session
  map.register '/register/:activation_code', :controller => 'activations', :action => 'new'
  map.activate '/activate/:id', :controller => 'activations', :action => 'create'
  
  map.resources :activations, :member => { :send_invite => :put },
                              :collection => { :bulk_send_invite => :put }
  map.resources :home, :only => :index
  map.resources :ticket_fields, :only => :index
  map.resources :email, :only => [:new, :create]
  map.resources :password_resets, :except => [:index, :show, :destroy]
  map.resources :sso, :collection => {:login => :get, :facebook => :get}
  map.namespace :integrations do |integration|
    integration.resources :installed_applications, :member =>{:install => :put, :uninstall => :get}
    integration.resources :applications, :member=>{:custom_widget_preview => :post}
    integration.resources :integrated_resource, :member =>{:create => :put, :delete => :delete}
    integration.resources :google_accounts, :member =>{:edit => :get, :delete => :delete, :update => :put, :import_contacts => :put}
    integration.resources :gmail_gadgets, :collection =>{:spec => :get}
    integration.resources :jira_issue, :collection => {:get_issue_types => :get, :unlink => :put, :notify => :post, :register => :get}
    integration.resources :salesforce, :collection => {:fields_metadata => :get}
    integration.resources :logmein, :collection => {:rescue_session => :get, :update_pincode => :put, :refresh_session => :get, :tech_console => :get, :authcode => :get}
    integration.oauth_action '/refresh_access_token/:provider', :controller => 'oauth_util', :action => 'get_access_token'
    integration.custom_install 'oauth_install/:provider', :controller => 'applications', :action => 'oauth_install'
  end

  map.namespace :admin do |admin|
    admin.resources :home, :only => :index
    admin.resources :day_passes, :only => [:index, :update], :member => { :buy_now => :put, :toggle_auto_recharge => :put }
    admin.resources :widget_config, :only => :index
    admin.resources :automations, :member => { :deactivate => :put, :activate => :put }, :collections => { :reorder => :put }
    admin.resources :va_rules, :member => { :deactivate => :put, :activate => :put }, :collections => { :reorder => :put }
    admin.resources :supervisor_rules, :member => { :deactivate => :put, :activate => :put }, 
      :collections => { :reorder => :put }
    admin.resources :email_configs, :member => { :make_primary => :put, :deliver_verification => :get, :test_email => :put}
    admin.register_email '/register_email/:activation_code', :controller => 'email_configs', :action => 'register_email'
    admin.resources :email_notifications
    admin.resources :getting_started, :collection => {:rebrand => :put}
    admin.resources :business_calender, :member => { :update => :put }
    admin.resources :security, :member => { :update => :put }
    admin.resources :data_export, :collection => {:export => :any }
    admin.resources :canned_responses
    admin.resources :portal, :only => [ :index, :update ]
    admin.namespace :canned_responses do |ca_response|
      ca_response.resources :folders do |folder|
        folder.resources :responses, :collection => { :delete_multiple => :delete, :update_folder => :put }
      end
    end
    admin.resources :products
    admin.resources :portal, :only => [ :index, :update] do |portal|
      portal.resource :template, 
                      :collection => { :show =>:get, :update => :put, :soft_reset => :put, 
                                        :restore_default => :get, :publish => :get } do |template|
        template.resources :pages, :member => { :edit_by_page_type => :get, :soft_reset => :put }
      end
    end
    admin.resources :surveys, :collection => { :enable => :post, :disable => :post }
    admin.resources :gamification, :collection => { :toggle => :post, :quests => :get, :update_game => :put }
    admin.resources :quests, :member => { :toggle => :put }
    admin.resources :zen_import, :collection => {:import_data => :any }
    admin.resources :email_commands_setting, :member => { :update => :put }
    admin.resources :account_additional_settings, :member => { :update => :put, :assign_bcc_email => :get}
  end
  
  map.resources :reports
  map.resources :timesheet_reports , :controller => 'reports/timesheet_reports' , :collection => {:report_filter => :post , :export_csv => :post} 
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
                :collection =>  { :feed => :any, :create_twicket => :post, :send_tweet => :any, :signin => :any, :tweet_exists => :get , :user_following => :any, :authdone => :any },
                :member     =>  { :search => :any, :edit => :any }

    social.resources :facebook, :controller => 'facebook_pages', 
                :collection =>  { :signin => :any ,:authdone => :any , :event_listener =>:any , :enable_pages =>:any },
                :member     =>  { :edit => :any }
  end
  
  #SAAS copy starts here
  map.with_options(:conditions => {:subdomain => AppConfig['admin_subdomain']}) do |subdom|
    subdom.root :controller => 'subscription_admin/subscriptions', :action => 'index'
    subdom.with_options(:namespace => 'subscription_admin/', :name_prefix => 'admin_', :path_prefix => nil) do |admin|
      admin.resources :subscriptions, :member => { :charge => :post, :extend_trial => :post, :add_day_passes => :post }, :collection => {:customers => :get, :customers_csv => :get}
      admin.resources :accounts, :collection => {:agents => :get, :helpdesk_urls => :get, :tickets => :get, :renewal_csv => :get}
      admin.resources :subscription_plans, :as => 'plans'
      admin.resources :subscription_discounts, :as => 'discounts'
      admin.resources :subscription_affiliates, :as => 'affiliates', :collection => {:add_affiliate_transaction => :post}
      admin.resources :subscription_payments, :as => 'payments'
      admin.resources :subscription_announcements, :as => 'announcements'
      admin.resources :conversion_metrics, :as => 'metrics'
      admin.namespace :resque do |resque|
        resque.home '', :controller => 'home', :action => 'index'
        resque.failed_show '/failed/:queue_name/show', :controller => 'failed', :action => 'show'
        resque.resources :failed, :member => { :destroy => :delete , :requeue => :put }, :collection => { :destroy_all => :delete }
      end
      admin.resources :analytics 
    end
  end
  
  map.with_options(:conditions => {:subdomain => AppConfig['partner_subdomain']}) do |subdom|
    subdom.with_options(:namespace => 'partner_admin/', :name_prefix => 'partner_', :path_prefix => nil) do |partner|
      partner.resources :affiliates, :collection => {:add_affiliate_transaction => :post}
    end
  end

  map.namespace :widgets do |widgets|
    widgets.resource :feedback_widget, :member => { :loading => :get } 
  end 

  map.plans '/signup', :controller => 'accounts', :action => 'plans'
  map.connect '/signup/d/:discount', :controller => 'accounts', :action => 'plans'
  map.thanks '/signup/thanks', :controller => 'accounts', :action => 'thanks'
  map.create '/signup/create/:discount', :controller => 'accounts', :action => 'create', :discount => nil
  map.resource :account, :collection => {:rebrand => :put, :dashboard => :get, :thanks => :get,   :cancel => :any, :canceled => :get , :signup_google => :any }
  map.resource :subscription, :collection => { :plans => :get, :billing => :any, :plan => :any, :calculate_amount => :any, :free => :get, :convert_subscription_to_free => :put }

  map.new_account '/signup/:plan/:discount', :controller => 'accounts', :action => 'new', :plan => nil, :discount => nil
  
  map.forgot_password '/account/forgot', :controller => 'user_sessions', :action => 'forgot'
  map.reset_password '/account/reset/:token', :controller => 'user_sessions', :action => 'reset'
  
  map.resources :search, :only => :index, :member => { :suggest => :get }
  
  
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

    helpdesk.resources :tags, :collection => { :autocomplete => :get }    

#    helpdesk.resources :issues, :collection => {:empty_trash => :delete}, :member => { :delete_all => :delete, :assign => :put, :restore => :put, :restore_all => :put } do |ticket|
#      ticket.resources :notes, :member => { :restore => :put }, :name_prefix => 'helpdesk_issue_helpdesk_'
#    end

    helpdesk.resources :tickets, :collection => { :user_tickets => :get, :empty_trash => :delete, :empty_spam => :delete, 
                                    :delete_forever => :delete, :user_ticket => :get, :search_tweets => :any, :custom_search => :get, 
                                    :export_csv => :post, :latest_ticket_count => :post, :add_requester => :post,
                                    :filter_options => :get, :full_paginate => :get },  
                                 :member => { :reply_to_conv => :get, :forward_conv => :get, :view_ticket => :get, 
                                    :assign => :put, :restore => :put, :spam => :put, :unspam => :put, :close => :post, 
                                    :execute_scenario => :post, :close_multiple => :put, :pick_tickets => :put, 
                                    :change_due_by => :put, :split_the_ticket =>:post, 
                                    :merge_with_this_request => :post, :print => :any, :latest_note => :get, 
                                    :clear_draft => :delete, :save_draft => :post } do |ticket|


      ticket.resources :notes, :member => { :restore => :put }, :name_prefix => 'helpdesk_ticket_helpdesk_'
      ticket.resources :subscriptions, :name_prefix => 'helpdesk_ticket_helpdesk_'
      ticket.resources :tag_uses, :name_prefix => 'helpdesk_ticket_helpdesk_'
      ticket.resources :reminders, :name_prefix => 'helpdesk_ticket_helpdesk_'
      ticket.resources :time_sheets, :name_prefix => 'helpdesk_ticket_helpdesk_' 

    end

    #helpdesk.resources :ticket_issues

    helpdesk.resources :leaderboard, :collection => { :mini_list => :get, :agents => :get, 
      :groups => :get }, :only => [ :mini_list, :agents, :groups ]
    helpdesk.resources :quests, :only => [ :active, :index, :unachieved ], 
      :collection => { :active => :get, :unachieved => :get }

    helpdesk.resources :notes
    helpdesk.resources :bulk_ticket_actions , :collection => {:update_multiple => :put}
    helpdesk.resources :ca_folders
    helpdesk.resources :canned_responses, :collection => {:search => :get, :recent => :get}
    helpdesk.resources :reminders, :member => { :complete => :put, :restore => :put }
    helpdesk.resources :time_sheets, :member => { :toggle_timer => :put}    

    helpdesk.filter_tag_tickets    '/tags/:id/*filters', :controller => 'tags', :action => 'show'
    helpdesk.filter_tickets        '/tickets/filter/tags', :controller => 'tags', :action => 'index'
    helpdesk.filter_view_default   '/tickets/filter/:filter_name', :controller => 'tickets', :action => 'index'
    helpdesk.filter_view_custom    '/tickets/view/:filter_key', :controller => 'tickets', :action => 'index'

    #helpdesk.filter_issues '/issues/filter/*filters', :controller => 'issues', :action => 'index'

    helpdesk.formatted_dashboard '/dashboard.:format', :controller => 'dashboard', :action => 'index'
    helpdesk.dashboard '', :controller => 'dashboard', :action => 'index'

#   helpdesk.resources :dashboard, :collection => {:index => :get, :tickets_count => :get}

    helpdesk.resources :articles, :collection => { :autocomplete => :get }

    helpdesk.resources :attachments
    
    helpdesk.resources :authorizations, :collection => { :autocomplete => :get, :agent_autocomplete => :get, :requester_autocomplete => :get }
    
    helpdesk.resources :mailer, :collection => { :fetch => :get }
    
    helpdesk.resources :sla_details
    
    helpdesk.resources :support_plans
    
    helpdesk.resources :sla_policies 

    helpdesk.resources :notifications, :only => :index

    helpdesk.resources :commons 
    
  end
  
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

  # Removing the home as it is redundant route to home - by venom  
  # map.resources :home, :only => :index 

  # Theme for the support portal
  map.connect "/theme.:format", :controller => 'theme'

  # Support Portal routes  
  map.namespace :support do |support|
    # Portal home
    support.home 'home', :controller => "home"
    
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
    support.resources :search, :only => :index, :member => { :suggest => :get }

    # Forums for the portal, the items will be name spaced by discussions
    support.resources :discussions, :only => [:index, :show]
    support.namespace :discussions do |discussion|
      discussion.resources :forums, :only => :show
      discussion.resources :topics, :except => :index, :member => { :like => :put, 
          :unlike => :put, :toggle_monitor => :put, :users_voted => :get } do |topic|
        topic.resources :posts, :only => [:create, :edit, :update, :toggle_monitor], 
          :member => { :toggle_answer => :put }
      end
    end

    # Solutions for the portal
    support.resources :solutions, :only => [:index, :show]
    support.namespace :solutions do |solution|
      solution.resources :folders, :only => :show
      solution.resources :articles, :only => :show, :member => { :thumbs_up => :put, 
        :thumbs_down => :put , :create_ticket => :post }
    end

    # !PORTALCSS TODO The below is a access routes for accessing routes without the solutions namespace
    # Check with shan if we really need this route or the one with the solution namespace
    support.resources :articles, :controller => 'solutions/articles', 
      :member => { :thumbs_up => :put, :thumbs_down => :put , :create_ticket => :post }

    # Tickets for the portal
    # All portal tickets including company_tickets are now served from this controller
    support.resources :tickets, 
      :collection => { :check_email => :get, :configure_export => :get, :filter => :get }, 
      :member => { :close => :post, :add_people => :put } do |ticket|

      ticket.resources :notes, :name_prefix => 'support_ticket_helpdesk_'
    end

    support.portal_survey '/surveys/:ticket_id', :controller => 'surveys', :action => 'create_for_portal'
    support.customer_survey '/surveys/:survey_code/:rating/new', :controller => 'surveys', :action => 'new'
    support.survey_feedback '/surveys/:survey_code/:rating', :controller => 'surveys', :action => 'create', 
      :conditions => { :method => :post }

  end
  
  map.namespace :anonymous do |anonymous|
    anonymous.resources :requests
  end

  map.namespace :mobile do |mobile|
    mobile.resources :tickets, :collection =>{:view_list => :get, :get_portal => :get, :get_suggested_solutions => :get, :ticket_properties => :get}
  end
  
  map.root :controller => "home"
  #map.connect '', :controller => 'helpdesk/dashboard', :action => 'index'
  
  # End routes to be included in final engine

  # Install the default routes as the lowest priority.
  # Note: These default routes make all actions in every controller accessible via GET requests. You should
  # consider removing the them or commenting them out if you're using named routes and resources.
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
  
end
