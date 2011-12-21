 ActionController::Routing::Routes.draw do |map|
      
  map.connect '/images/helpdesk/attachments/:id/:style.:format', :controller => '/helpdesk/attachments', :action => 'show', :conditions => { :method => :get }
  
  # Routing for Asset management Jammit
  Jammit::Routes.draw(map)
  
  map.resources :authorizations
  map.callback '/auth/:provider/callback', :controller => 'authorizations', :action => 'create'
  map.failure '/auth/failure', :controller => 'authorizations', :action => 'failure'
  
  map.resources :uploaded_images, :controller => 'uploaded_images'
  
  map.resources :import , :controller => 'contact_import'
  
  map.resources :customers ,:member => {:quick => :post}
 
  map.resources :contacts, :collection => { :autocomplete => :get } , :member => { :restore => :put,:quick_customer => :post ,:make_agent =>:put}
  
  map.resources :groups
  
  map.resources :profiles , :member => { :change_password => :post}
  
  map.resources :agents, :member => { :delete_avatar => :delete , :restore => :put }

  map.resources :sla_details
  
  #map.resources :support_plans

  map.resources :sl_as

  map.logout '/logout', :controller => 'user_sessions', :action => 'destroy'
  map.gauth '/auth/google', :controller => 'user_sessions', :action => 'google_auth'
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
  map.resources :users, :member => { :delete_avatar => :delete, :change_account_admin => :put,:block => :put }
  map.resource :user_session
  map.register '/register/:activation_code', :controller => 'activations', :action => 'new'
  map.activate '/activate/:id', :controller => 'activations', :action => 'create'
  map.resources :activations, :member => { :send_invite => :put }
  map.resources :home, :only => :index
  map.resources :ticket_fields, :only => :index
  map.resources :email, :only => [:new, :create]
  map.resources :password_resets, :except => [:index, :show, :destroy]

  map.namespace :integrations do |integration|
    integration.resources :installed_applications, :member =>{:install => :put, :uninstall => :get, :configure => :get, :update => :put}
    integration.resources :applications, :member =>{:show => :get}
  end

  map.namespace :admin do |admin|
    admin.resources :home, :only => :index
    admin.resources :widget_config, :only => :index
    admin.resources :automations, :member => { :deactivate => :put, :activate => :put }, :collections => { :reorder => :put }
    admin.resources :va_rules, :member => { :deactivate => :put, :activate => :put }, :collections => { :reorder => :put }
    admin.resources :supervisor_rules, :member => { :deactivate => :put, :activate => :put }, 
      :collections => { :reorder => :put }
    admin.resources :email_configs, :member => { :make_primary => :put, :deliver_verification => :get }
    admin.register_email '/register_email/:activation_code', :controller => 'email_configs', :action => 'register_email'
    admin.resources :email_notifications
    admin.resources :business_calender, :member => { :update => :put }
    admin.resources :security, :member => { :update => :put }
    admin.resources :data_export, :collection => {:export => :any }
    admin.resources :portal, :only => [ :index, :update ]
    admin.resources :canned_responses
    admin.resources :products
    admin.resources :surveys, :only => [ :index ]
    admin.resources :zen_import, :collection => {:import_data => :any }
  end
  map.resources :reports
  map.timesheet_report    '/timesheet_reports', :controller => 'reports/timesheet_reports', :action => 'index'
  map.customer_activity   '/activity_reports/customer', :controller => 'reports/customer_reports', :action => 'index'
  map.helpdesk_activity   '/activity_reports/helpdesk', :controller => 'reports/helpdesk_reports', :action => 'index'

  
  map.namespace :social do |social|
    social.resources :twitters, :controller => 'twitter_handles',
                :collection =>  { :feed => :any, :create_twicket => :post, :send_tweet => :any, :signin => :any, :tweet_exists => :get },
                :member     =>  { :search => :any, :edit => :any }

    social.resources :facebook, :controller => 'facebook_pages', 
                :collection =>  { :signin => :any ,:authdone => :any , :event_listener =>:any , :enable_pages =>:any },
                :member     =>  { :edit => :any }
  end
  
  #SAAS copy starts here
  map.with_options(:conditions => {:subdomain => AppConfig['admin_subdomain']}) do |subdom|
    subdom.root :controller => 'subscription_admin/subscriptions', :action => 'index'
    subdom.with_options(:namespace => 'subscription_admin/', :name_prefix => 'admin_', :path_prefix => nil) do |admin|
      admin.resources :subscriptions, :member => { :charge => :post, :extend_trial => :post }, :collection => {:customers => :get, :customers_csv => :get}
      admin.resources :accounts, :collection => {:agents => :get, :helpdesk_urls => :get, :tickets => :get, :renewal_csv => :get}
      admin.resources :subscription_plans, :as => 'plans'
      admin.resources :subscription_discounts, :as => 'discounts'
      admin.resources :subscription_affiliates, :as => 'affiliates'
      admin.resources :subscription_payments, :as => 'payments'
    end
  end
  
  map.namespace :widgets do |widgets|
    widgets.resource :feedback_widget, :member => { :loading => :get } 
  end 

  map.plans '/signup', :controller => 'accounts', :action => 'plans'
  map.connect '/signup/d/:discount', :controller => 'accounts', :action => 'plans'
  map.thanks '/signup/thanks', :controller => 'accounts', :action => 'thanks'
  map.create '/signup/create/:discount', :controller => 'accounts', :action => 'create', :discount => nil
  map.resource :account, :collection => { :dashboard => :get, :thanks => :get, :plans => :get, :billing => :any, :paypal => :any, :plan => :any, :plan_paypal => :any, :cancel => :any, :canceled => :get , :signup_google => :any, :calculate_amount => :any }
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
    helpdesk.resources :time_sheets
    

#    helpdesk.resources :issues, :collection => {:empty_trash => :delete}, :member => { :delete_all => :delete, :assign => :put, :restore => :put, :restore_all => :put } do |ticket|
#      ticket.resources :notes, :member => { :restore => :put }, :name_prefix => 'helpdesk_issue_helpdesk_'
#    end

    helpdesk.resources :tickets, :collection => { :empty_trash => :delete, :empty_spam => :delete, :user_ticket => :get, :search_tweets => :any, :custom_search => :get, :export_csv => :post }, 
                                 :member => { :assign => :put, :restore => :put, :spam => :put, :unspam => :put, :close => :put, :execute_scenario => :post  , :close_multiple => :put, :pick_tickets => :put, :change_due_by => :put , :get_ca_response_content => :post ,:split_the_ticket =>:post , :merge_with_this_request => :post, :print => :any } do |ticket|

      ticket.resources :notes, :member => { :restore => :put }, :name_prefix => 'helpdesk_ticket_helpdesk_'
      ticket.resources :subscriptions, :name_prefix => 'helpdesk_ticket_helpdesk_'
      ticket.resources :tag_uses, :name_prefix => 'helpdesk_ticket_helpdesk_'
      ticket.resources :reminders, :name_prefix => 'helpdesk_ticket_helpdesk_'
      
    end

    #helpdesk.resources :ticket_issues

    helpdesk.resources :notes

    helpdesk.resources :reminders, :member => { :complete => :put, :restore => :put }

    helpdesk.filter_tag_tickets    '/tags/:id/*filters', :controller => 'tags', :action => 'show'
    helpdesk.filter_tickets        '/tickets/filter/tags', :controller => 'tags', :action => 'index'
    helpdesk.filter_view_default   '/tickets/filter/:filter_name', :controller => 'tickets', :action => 'index'
    helpdesk.filter_view_custom    '/tickets/view/:filter_key', :controller => 'tickets', :action => 'index'


    #helpdesk.filter_issues '/issues/filter/*filters', :controller => 'issues', :action => 'index'

    helpdesk.formatted_dashboard '/dashboard.:format', :controller => 'dashboard', :action => 'index'
    helpdesk.dashboard '', :controller => 'dashboard', :action => 'index'


    helpdesk.resources :articles, :collection => { :autocomplete => :get }

    helpdesk.resources :article_guides

    helpdesk.resources :attachments

    helpdesk.resources :guides, :member => { :reorder_articles => :put, :privatize => :put, :publicize => :put }, :collection => { :reorder => :put }
    
    helpdesk.resources :authorizations, :collection => { :autocomplete => :get, :agent_autocomplete => :get }
    
    helpdesk.resources :mailer, :collection => { :fetch => :get }
    
    helpdesk.resources :sla_details
    
    helpdesk.resources :support_plans
    
    helpdesk.resources :sla_policies   
    
  end
  
   map.namespace :solution do |solution|     
     solution.resources :categories  do |category|   
     category.resources :folders  do |folder|
       folder.resources :articles, :member => { :thumbs_up => :put, :thumbs_down => :put , :delete_tag => :post } do |article|
         article.resources :tag_uses
       end
       end
     end
     
     solution.resources :articles, :only => :show
         
     end

  map.namespace :support do |support|
    support.resources :guides 
     support.resources  :articles, :member => { :thumbs_up => :put, :thumbs_down => :put , :create_ticket => :post }
       support.resources :tickets do |ticket|
      ticket.resources :notes, :name_prefix => 'support_ticket_helpdesk_'
    end
    support.resources :company_tickets
    support.resources :minimal_tickets
    support.resources :registrations
    support.map '', :controller => 'guides', :action => 'index'
    
    support.customer_survey '/surveys/:survey_code/:rating/new', :controller => 'surveys', :action => 'new'
    support.survey_feedback '/surveys/:survey_code/:rating', :controller => 'surveys', :action => 'create', 
        :conditions => { :method => :post }
  end
  
  map.namespace :anonymous do |anonymous|
    anonymous.resources :requests
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
