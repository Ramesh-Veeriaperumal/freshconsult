Helpkit::Application.routes.draw do
  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'



  constraints(lambda {|req| req.subdomain == AppConfig['admin_subdomain'] }) do

    root :to => 'subscription_admin/subscriptions#index'

    match '/plans' => 'subscription_admin/subscription_plans#index', :as => :plans
    match '/affiliates' => 'subscription_admin/subscription_affiliates#index', :as => :affiliates
    match '/customers' => 'subscription_admin/subscriptions#customers', :as => :customers
    match '/resque' => 'subscription_admin/resque/home#index', :as => :home
    match '/resque/failed/:queue_name/show' => 'subscription_admin/resque/failed#show', :as => :failed_show
    match '/resque/failed/destroy_all' => 'subscription_admin/resque/failed#destroy_all', :as => :failed_destroy_all
    match '/resque/failed/requeue_all' => 'subscription_admin/resque/failed#requeue_all', :as => :failed_requeue_all
    match '/resque/failed/:id' => 'subscription_admin/resque/failed#destroy', :as => :failed_destroy
    match '/resque/failed/:id/requeue' => 'subscription_admin/resque/failed#requeue', :as => :failed_requeue

    namespace :resque do
      resources :failed, :controller => '/subscription_admin/resque/failed' do
      end
    end

    namespace :subscription_admin, :as => 'admin' do
      resources :subscriptions do
        collection do
          get :deleted_customers
          get :customers_csv
        end
      end

      resources :accounts do
        member do
          post :add_day_passes
        end
        collection do
          get :agents
          get :tickets
          get :renewal_csv
        end
      end

      resources :subscription_affiliates do
        collection do
          post :new
          post :add_affiliate_transaction
        end
        member do
          post :add_subscription
        end
      end

      resources :subscription_payments, :as => 'payments'
      resources :subscription_announcements, :as => 'announcements'
      resources :conversion_metrics, :as => 'metrics'

      resources :account_tools, :as => 'tools' do
        collection do
          post :regenerate_reports_data
          put :update_global_blacklist_ips
        end
      end

      resources :manage_users, :as => 'manage_users' do
        collection do
          post :add_whitelisted_user_id
          post :remove_whitelisted_user_id
        end
      end

      match '/freshfone_admin' => 'freshfone_subscriptions#index', :as => :freshfone

      match '/freshfone_admin/stats' => 'freshfone_stats#index', :as => :freshfone_stats

      resources :spam_watch, :only => :index
      match ':shard_name/spam_watch/:user_id/:type' => 'spam_watch#spam_details'

      match ':shard_name/spam_user/:user_id' => 'spam_watch#spam_user', :as => :spam_user

      match ':shard_name/block_user/:user_id' => 'spam_watch#block_user'
      match ':shard_name/hard_block/:user_id' => 'spam_watch#hard_block', :as => :hard_block_user
      match ':shard_name/internal_whitelist/:user_id' => 'spam_watch#internal_whitelist', :as => :internal_whitelist


      resources :subscription_events, :as => 'events' do
        collection do
          get :export_to_csv
        end
      end

      resources :custom_ssl, :as => 'customssl' do
        collection do
          post :enable_custom_ssl
        end
      end

      resources :currencies, :as => 'currency'

      resources :admin_sessions, :only => [:create, :destroy]

      match 'admin_sessions/logout' => 'admin_sessions#destroy', :as => :subscription_logout

      match 'admin_sessions/login' => 'admin_sessions#new', :as => :subscription_login

      resources :subscription_users, :as => 'subscription_users' do
        member do
          post :update
          get :edit
          get :show
        end

        collection do
          put :reset_password
        end
      end
    end
  end

  root :to => 'home#index'

  match '/visitor/load/:id.:format' => 'chats#load', :via => :get
  match '/images/helpdesk/attachments/:id(/:style(.:format))' => 'helpdesk/attachments#show', :via => :get
  match '/javascripts/:action.:format' => 'javascripts#index'
  match '/packages/:package.:extension' => 'jammit#package', :as => :jammit, :constraints => { :extension => /.+/ }
  resources :authorizations
  match '/google_sync' => 'authorizations#sync', :as => :google_sync
  match '/auth/google_login/callback' => 'google_login#create_account_from_google', :as => :callback
  match '/auth/:provider/callback' => 'authorizations#create', :as => :callback
  match '/oauth2callback' => 'authorizations#create', :as => :calender, :provider => 'google_oauth2'
  match '/auth/failure' => 'authorizations#failure', :as => :failure
  resources :solutions_uploaded_images, :only => [:index, :create]
  resources :forums_uploaded_images, :only => :create
  resources :tickets_uploaded_images, :only => :create

  resources :contact_import do
    collection do
      get :csv
      get :google
    end
  end

  resources :health_check

  resources :customers do
    member do
      post :quick
      get :sla_policies
    end
    collection do
      delete :destroy
      post :quick
    end
    resources :time_sheets, :controller=>'helpdesk/time_sheets'
  end

  resources :companies do
    member do
      post :quick
      get :sla_policies
      post :create_company
      put :update_company
      put :update_notes
    end
    collection do
      delete :destroy
      post :quick
      post :create_company
    end
    resources :time_sheets, :controller=>'helpdesk/time_sheets'
  end

  match '/customers/filter/:state/*letter' => 'customers#index'
  match '/companies/filter/:state/*letter', :controller => 'companies', :action => 'index'
  get '/contacts' => 'contacts#index'

  resources :contacts do
    collection do
      get :contact_email
      get :autocomplete
      post :configure_export
      get :show
      post :export_csv
      get :verify_email
      put :make_agent
      post :unblock
      post :restore
      post :create_contact
    end

    member do
      get :hover_card
      get :hover_card_in_new_tab
      put :restore
      post :quick_customer
      post :quick_contact_with_company
      put :make_agent
      put :make_occasional_agent
      put :verify_email
      get :unblock
      post :create_contact
      put :update_contact
      put :update_description_and_tags
    end
    resources :contact_merge do
      collection do
        get :search
      end
    end
  end

  resources :contact_merge do
    collection do
      get :search
      post :new
      post :confirm
      post :complete
      post :merge
    end
  end

  match '/contacts/filter/:state(/*letter)' => 'contacts#index'
  resources :groups

  resources :user_emails do
    member do
      get :make_primary
    end
    collection do
      put :send_verification
    end
  end

  resources :profiles do
    collection do
      post :reset_api_key
      post :change_password
      put :notification_read
    end
    member do
      post :change_password
    end
    resources :user_emails do

      member do
        get :make_primary
        put :send_verification
      end
    end
  end

  resources :agents do
    collection do
      put :create_multiple_items
      get :info_for_node
    end
    member do
      put :toggle_shortcuts
      put :restore
      get :convert_to_user
      put :reset_password
      put :convert_to_contact
      post :toggle_availability
    end
    resources :time_sheets
  end

  match '/agents/filter/:state(/*letter)' => 'agents#index'
  match '/logout' => 'user_sessions#destroy', :as => :logout
  match '/oauth/googlegadget' => 'user_sessions#oauth_google_gadget', :as => :gauth
  match '/opensocial/google' => 'user_sessions#opensocial_google', :as => :gauth
  match '/authdone/google' => 'user_sessions#google_auth_completed', :as => :gauth_done
  match '/login' => 'user_sessions#new', :as => :login
  match '/login/sso' => 'user_sessions#sso_login', :as => :sso_login
  match '/login/saml' => 'user_sessions#saml_login', :as => :saml_login
  match '/login/normal' => 'user_sessions#new', :as => :login_normal
  match '/signup_complete/:token' => 'user_sessions#signup_complete', :as => :signup_complete
  match '/google/complete' => 'accounts#openid_complete', :as => :openid_done
  match '/zendesk/import' => 'admin/zen_import#index', :as => :zendesk_import
  match '/twitter/authdone' => 'social/twitter_handles#authdone', :as => :tauth
  match '/download_file/:source/:token' => 'admin/data_export#download', :as => :download_file
  namespace :freshfone do
    resources :ivrs do
      member do
        post :activate
        post :deactivate
      end
    end

    resources :call do
      collection do
        post :status
        post :in_call
        post :direct_dial_success
        get :inspect_call
        get :caller_data
        post :call_transfer_success
      end
    end

    resources :queue do
      collection do
        post :enqueue
        post :dequeue
        post :quit_queue_on_voicemail
        post :trigger_voicemail
        post :trigger_non_availability
        post :bridge
        post :hangup
      end
    end

    resources :voicemail do
      collection do
        post :quit_voicemail
      end
    end

    resources :call_transfer do
      collection do
        post :initiate
        post :transfer_incoming_call
        post :transfer_outgoing_call
        post :transfer_incoming_to_group
        post :transfer_outgoing_to_group
        get :available_agents
      end
    end

    resources :device do
      collection do
        post :record
        get :recorded_greeting
      end
    end

    resources :call_history do
      collection do
        get :custom_search
        get :children
        get :recent_calls
      end
    end

    resources :blacklist_number do
      collection do
        post :create
      end
      member do
        delete :destroy
      end
    end

    resources :users do
      collection do
        post :presence
        post :node_presence
        post :availability_on_phone
        post :refresh_token
        post :in_call
        post :reset_presence_on_reconnect
      end
    end

    resources :autocomplete do
      collection do
        get :requester_search
        get :customer_phone_number
      end
    end
    resources :usage_triggers do
      collection do
        post :notify
      end
    end

    resources :ops_notification do
      collection do
        post :voice_notification
        post :status
      end
    end
  end

  resources :freshfone do
    collection do
      post :voice
      post :build_ticket
      get :dashboard_stats
      get :get_available_agents
      get :credit_balance
      post :ivr_flow
      post :voice_fallback
      post :create_note
      post :create_ticket
    end
  end

  match '/freshfone/preview_ivr/:id' => 'freshfone#preview_ivr', :via => :post

  resources :users do
    collection do
      get :revert_identity
    end
    member do
      delete :delete_avatar
      put :block
      get :assume_identity
      get :profile_image
    end
  end

  resource :user_session

  match '/register/:activation_code' => 'activations#new', :as => :register
  match 'register_new_email/:activation_code' => 'activations#new_email', :as => :register_new_email
  match '/activate/:perishable_token' => 'activations#create', :as => :activate

  resources :activations do
    member do
      put :send_invite
    end
  end

  resources :home, :only => :index
  resources :ticket_fields, :only => :index do
    collection do
      put :update
    end
  end
  resources :email, :only => [:new, :create]
  resources :mailgun, :only => :create
  resources :password_resets, :except => [:index, :show, :destroy]

  resources :sso do
    collection do
      get :login
      get :facebook
      get :google_login
    end
  end

  resource :account_configuration

  namespace :integrations do
    resources :installed_applications do
      member do
        put :install
        get :uninstall
      end
    end

    resources :remote_configurations

    resources :applications do
      member do
        post :custom_widget_preview
      end
      collection do
        post :oauth_install
        get :custom_widget_preview
      end
    end

    resources :integrated_resources do
      collection do
        delete :delete
      end
      member do
        post :create
      end
    end

    resources :google_accounts do
      member do
        get :edit
        delete :delete
        put :update
        put :import_contacts
      end
      collection do
        post :update
        get :edit
      end
    end

    resources :gmail_gadgets do
      collection do
        get :spec
      end
    end

    match '/jira_issue/unlink' => 'jira_issue#unlink'
    match 'jira_issue/destroy' => 'jira_issue#destroy'
    match 'jira_issue/update' => 'jira_issue#update'

    resources :jira_issue do
      collection do
        get :get_issue_types
        post :notify
        get :register
        post :fetch_jira_projects_issues #todo : check this route action
      end
      member do
        post :create

      end

    end

    resources :pivotal_tracker do
      collection do
        get :tickets
        post :pivotal_updates
        post :update_config
      end
    end

    resources :user_credentials do
      collection do
        post :oauth_install
      end
    end

    resources :logmein do
      collection do
        get :rescue_session
        put :update_pincode
        get :refresh_session
        get :tech_console
        get :authcode
      end
    end

    namespace :cti do
      resources :customer_details do
        collection do 
          get :fetch 
          post :create_note
          post :create_ticket
        end
      end
    end

    match '/refresh_access_token/:app_name' => 'oauth_util#get_access_token', :as => :oauth_action
    match '/applications/oauth_install/:id' => 'applications#oauth_install', :as => :custom_install
    match '/user_credentials/oauth_install/:id' => 'user_credentials#oauth_install', :as => :custom_install_user
    match 'install/:app' => 'oauth#authenticate', :as => :oauth
  end

  resources :http_request_proxy do
    collection do
      post :fetch
    end
  end

  namespace :admin do
    resources :home, :only => :index
    resources :contact_fields, :only => :index do
      collection do
        put :update
      end
    end
    
    resources :company_fields, :only => :index do
      collection do
        put :update
      end
    end

    resources :day_passes, :only => [:index, :update] do
      member do
        put :buy_now
        put :toggle_auto_recharge
      end
      collection do
        post :update
        put :buy_now
        put :toggle_auto_recharge
      end
    end

    resources :widget_config, :only => :index
    resources :chat_widgets do
      member do
        post :update
      end
    end

    resources :va_rules do
      collection do
        put :reorder
        post :toggle_cascade
      end
      member do
        put :activate_deactivate
        get :clone_rule
      end
    end

    resources :supervisor_rules do
      collection do
        put :reorder
      end
      member do
        put :activate_deactivate
        get :clone_rule
      end
    end

    resources :observer_rules do
      collection do
        put :reorder
      end
      member do
        put :activate_deactivate
        get :clone_rule
      end
    end

    resources :email_configs do
      collection do
        get :existing_email
        post :personalized_email_enable
        post :personalized_email_disable
        post :reply_to_email_enable
        post :reply_to_email_disable
        post :id_less_tickets_enable
        post :id_less_tickets_disable
        post :validate_mailbox_details
      end
      member do
        put :make_primary
        get :deliver_verification
        put :test_email
      end
    end
    match '/register_email/:activation_code' => 'email_configs#register_email', :as => :register_email
    resources :email_notifications do
      member do
        put :update_agents
      end
    end
    match '/email_notifications/:type/:id/edit' => 'email_notifications#edit', :as => :edit_notification
    resources :getting_started do
      collection do
        put :rebrand
        delete :delete_logo
      end
    end

    resources :business_calendars do
      collection do
        post :create
        post :holidays_list
        post :holidays
      end
    end

    resources :security do
      collection do
        post :request_custom_ssl
      end
      member do
        put :update
      end
    end

    resources :data_export do
      collection do
        get :export
      end
    end

    resources :portal, :only => [:index, :update]

    namespace :canned_responses do
      resources :folders do
        collection do
          get :edit
        end
        resources :responses do
          collection do
            put :update_folder
            delete :delete_multiple
          end
          member do
            delete :delete_shared_attachments
          end
        end
      end
    end

    resources :products do
      member do
        delete :delete_logo
        delete :delete_favicon
      end
    end

    resources :portal, :only => [:index, :update] do
      resource :template do
        collection do
          get :show
          put :update
          put :soft_reset
          get :restore_default
          get :publish
          get :clear_preview
        end

        resources :pages do
          member do
            get :edit_by_page_type
            put :soft_reset
          end
        end
      end
    end

    resources :surveys do
      collection do
        post :enable
        post :disable
        get :index
        put :update
      end
    end

    resources :gamification do
      collection do
        post :toggle
        get :quests
        put :update_game
      end
    end

    resources :quests do
      member do
        put :toggle
      end
    end

    resources :zen_import do
      collection do
        post :import_data
        get :status
      end
    end

    resources :email_commands_setting do
      member do
        put :update
      end
    end

    resources :account_additional_settings do
      collection do
        get :assign_bcc_email
        put :update
        put :update_font
      end
      member do
        put :update
        get :assign_bcc_email
      end
    end

    resources :freshfone, :only => [:index] do
      collection do
        get :search
        put :toggle_freshfone
        get :available_numbers
        post :request_freshfone_feature
      end
    end

    namespace :freshfone do
      resources :numbers do
        collection do
          post :purchase
          get :edit
        end
      end

      resources :credits do
        collection do
          put :disable_auto_recharge
          put :enable_auto_recharge
          post :purchase
          put  :purchase
        end
      end
    end

    resources :roles
    namespace :social do
      resources :streams, :only => :index
      resources :twitter_streams do
        collection do
          post :preview
        end
        member do
          post :delete_ticket_rule
        end
      end

      resources :twitters, :controller => :twitter_handles  do
        collection do
          get :authdone
        end
        member do
          delete :destroy
        end
      end
    end

    resources :mailboxes
    namespace :mobihelp do
      resources :apps
    end

    resources :dynamic_notification_templates do
      collection do
        put :update
      end
    end

    resources :email_commands_settings do
      collection do
        get :index
        put :update
      end
    end

  end

  namespace :search do
    resources :home, :only => :index do
      collection do
        get :suggest
      end
    end

    resources :autocomplete do
      collection do
        get :requesters
        get :agents
        get :companies
        get :tags
      end
    end

    resources :tickets, :only => :index
    resources :solutions, :only => :index
    resources :forums, :only => :index
    resources :customers, :only => :index
    match '/related_solutions/ticket/:ticket/' => 'solutions#related_solutions', :as => :ticket_related_solutions
    match '/search_solutions/ticket/:ticket/' => 'solutions#search_solutions', :as => :ticket_search_solutions
  end

  match '/search/tickets/filter/:search_field' => 'search/tickets#index'
  match '/search/all' => 'search/home#index'
  match '/search/topics.:format' => 'search/forums#index'
  match '/mobile/tickets/get_suggested_solutions/:ticket.:format' => 'search/solutions#related_solutions'
  match '/search/merge_topic', :controller => 'search/merge_topic', :action => 'index'

  namespace :reports do
    resources :helpdesk_glance_reports, :controller => 'helpdesk_glance_reports' do
      collection do
        post :generate
        post :generate_pdf
        post :send_report_email
        post :fetch_activity_ajax
        post :fetch_metrics
      end
    end

    resources :analysis_reports, :controller => 'helpdesk_load_analysis' do
      collection do
        post :generate
        post :generate_pdf
        post :send_report_email
      end
    end

    resources :performance_analysis_reports, :controller => 'helpdesk_performance_analysis' do
      collection do
        post :generate
        post :generate_pdf
        post :send_report_email
      end
    end

    resources :agent_glance_reports, :controller => 'agent_glance_reports' do
      collection do
        post :generate
        post :generate_pdf
        post :send_report_email
        post :fetch_activity_ajax
        post :fetch_metrics
      end
    end

    resources :group_glance_reports, :controller => 'group_glance_reports' do
      collection do
        post :generate
        post :generate_pdf
        post :send_report_email
        post :fetch_activity_ajax
        post :fetch_metrics
      end
    end

    resources :authorizations, :collection => { :autocomplete => :get, :agent_autocomplete => :get,
                                                :company_autocomplete => :get }

    resources :agent_analysis_reports, :controller => 'agents_analysis' do
      collection do
        post :generate
        post :generate_pdf
        post :send_report_email
        post :fetch_chart_data
      end
    end

    resources :group_analysis_reports, :controller => 'groups_analysis' do
      collection do
        post :generate
        post :generate_pdf
        post :send_report_email
        post :fetch_chart_data
      end
    end

    resources :agents_comparison_reports, :controller => 'agents_comparison' do
      collection do
        post :generate
        post :generate_pdf
        post :send_report_email
      end
    end

    resources :groups_comparison_reports, :controller => 'groups_comparison' do
      collection do
        post :generate
        post :generate_pdf
        post :send_report_email
      end
    end

    resources :customer_glance_reports, :controller => 'customer_glance_reports' do
      collection do
        post :generate
        post :generate_pdf
        post :send_report_email
        post :fetch_activity_ajax
        post :fetch_metrics
      end
    end

    resources :customers_analysis_reports, :controller => 'customers_analysis' do
      collection do
        post :generate
        post :generate_pdf
        post :send_report_email
        post :fetch_chart_data
      end
    end

    resources :report_filters do
      member do
        post :create
      end
    end


    namespace :freshfone do
      resources :summary_reports, :controller => 'summary_reports' do
        collection do
          post :generate
          post :export_csv
        end
      end
    end

    namespace :freshchat do
      resources :summary_reports, :controller => 'summary_reports' do
        collection do
          post :generate
        end
      end
    end
  end

  resources :reports
  match 'reports/report_filters/destroy/:id(.:format)' => "reports/report_filters#destroy", :method => :post


  resources :timesheet_reports , :controller => 'reports/timesheet_reports' do
    collection do
      post :report_filter
      post :export_csv
      post :generate_pdf
    end
  end

  match '/activity_reports/customer' => 'reports/customer_reports#index', :as => :customer_activity
  match '/activity_reports/helpdesk' => 'reports/helpdesk_reports#index', :as => :helpdesk_activity
  match '/activity_reports/customer/generate' => 'reports/customer_reports#generate', :as => :customer_activity_generate
  match '/activity_reports/helpdesk/generate' => 'reports/helpdesk_reports#generate', :as => :helpdesk_activity_generate
  match '/activity_reports/helpdesk/export_to_excel' => 'reports/helpdesk_reports#export_to_excel', :as => :helpdesk_activity_export
  match '/gamification/reports' => 'reports/gamification_reports#index', :as => :scoreboard_activity
  match '/survey/reports' => 'reports/survey_reports#index', :as => :survey_activity
  match '/survey/reports/:category/:view' => 'reports/survey_reports#index', :as => :survey_back_to_list
  match '/survey/reports_list' => 'reports/survey_reports#list', :as => :survey_list
  match '/survey/report_details/:entity_id/:category' => 'reports/survey_reports#report_details', :as => :survey_detail_report
  match '/survey/overall_report/:category' => 'reports/survey_reports#report_details', :as => :survey_overall_report
  match '/reports/survey_reports/feedbacks' => 'reports/survey_reports#feedbacks', :as => :survey_feedbacks
  match '/reports/survey_reports/refresh_details' => 'reports/survey_reports#refresh_details', :as => :survey_refresh_details

  namespace :social do

    resources :twitters, :controller => "twitter_handles" do
      collection do
        get :index
        get :show
        get :feed
        post :create_twicket
        post :send_tweet
        post :signin
        get :tweet_exists
        get :user_following
        put :authdone
        get :twitter_search
      end

      member do
        get :search
        get :edit
      end
    end

    resources :gnip, :controller => "gnip_twitter" do
      collection do
        post :reconnect
      end
    end

    resources :streams do
      collection do
        get :stream_feeds
        get :show_old
        get :fetch_new
        get :interactions
      end
    end

    resources :welcome, :only => :index do
      collection do
        get :get_stats
        post :enable_feature
      end
    end

    resources :twitter do
      collection do
        get :twitter_search
        get :show_old
        get :fetch_new
        post :create_fd_item
        get :user_info
        get :retweets
        post :reply
        post :retweet
        post :post_tweet
        post :favorite
        post :unfavorite
        get :followers
        post :follow
        post :unfollow
      end
    end
  end

  namespace :widgets do
    resource :feedback_widget do
      member do
        get :loading
      end
      collection do
        get :thanks
      end
    end
  end

  match '/signup' => 'accounts#plans', :as => :plans
  match '/signup/d/:discount' => 'accounts#plans'
  match '/signup/thanks' => 'accounts#thanks', :as => :thanks
  match '/signup/create/:discount' => 'accounts#create', :as => :create, :discount => nil

  resource :account do
    collection do
      put :rebrand
      get :dashboard
      get :thanks
      get :cancel
      post :cancel
      get :canceled
      post :signup_google
      delete :delete_logo
      delete :delete_favicon
      get :new_signup_free
    end
  end

  resource :accounts do
    collection do
      get :new_signup_free
    end
  end

  resource :subscription do
    collection do
      get :plans
      get :billing
      post :billing
      post :plan
      post :calculate_amount
      put :convert_subscription_to_free
      post :calculate_plan_amount
    end
  end

  match '/signup/:plan/:discount' => 'accounts#new', :as => :new_account, :plan => nil, :discount => nil
  match '/account/forgot' => 'user_sessions#forgot', :as => :forgot_password
  match '/account/reset/:token' => 'user_sessions#reset', :as => :reset_password
  match '/search_user_domain' => 'domain_search#locate_domain', :as => :search_domain
  match '/helpdesk/tickets/execute_scenario(/:id)' => 'helpdesk/tickets#execute_scenario' # For mobile apps backward compatibility


  namespace :helpdesk do
    resources :tags do
      collection do
        get :autocomplete
        delete :remove_tag
        put :rename_tags
        put :merge_tags
      end
    end

    resources :authorizations do
      collection do
        get :autocomplete
        get :company_autocomplete
        get :agent_autocomplete
      end
    end

    resources :tickets do
      collection do
        get :user_tickets
        delete :empty_trash
        delete :empty_spam
        delete :delete_forever
        get :user_ticket
        get :search_tweets
        post :custom_search
        post :export_csv
        post :latest_ticket_count
        post :add_requester
        get :filter_options
        get :full_paginate
        get :summary
        get :update_multiple_tickets
        get :configure_export
        get :custom_view_save
        post :assign_to_agent#TODO-RAILS3 new route
        put :quick_assign #TODO-RAILS3 new route
      end

      member do
        get :reply_to_conv
        get :forward_conv
        get :view_ticket
        put :assign
        put :restore
        put :spam
        put :unspam
        post :close
        post :execute_scenario
        put :close_multiple
        put :pick_tickets
        put :change_due_by
        post :split_the_ticket
        get :status
        post :merge_with_this_request
        get :print
        get :latest_note
        get :activities
        delete :clear_draft
        post :save_draft
        put :update_ticket_properties
        get :component
        get :prevnext
        post :create # For Mobile apps backward compatibility.
      end

      resources :surveys do
        collection do
          get :results
          post :rate
        end
      end

      resources :conversations do
        collection do
          post :reply
          post :forward
          post :note
          post :twitter
          post :facebook
          post :mobihelp
        end
      end

      resources :notes do
        collection do
          get :since
          get :agents_autocomplete
        end

        member do
          put :restore
        end
      end

      resources :subscriptions do
        collection do
          post :create_watchers
          get :unsubscribe
          delete :unwatch
          delete :unwatch_multiple
        end
      end

      resources :leaderboard, :only => [ :mini_list, :agents, :groups ] do
        collection do 
          get :mini_list 
          get :agents
          get :groups
        end
      end

      resources :quests, :only => [ :active, :index, :unachieved ] do
        collection do
          get :active
          get :unachieved
        end
      end
      resources :tag_uses
      resources :reminders
      resources :time_sheets
      resources :mobihelp_ticket_extras, :only => :index
    end
    
    match 'leaderboard/group_agents/:id', :controller => 'leaderboard', :action => 'group_agents', :as => 'leaderboard_group_users'

    resources :leaderboard, :only => [:mini_list, :agents, :groups] do
      collection do
        get :mini_list
        get :agents
        get :groups
      end
    end

    resources :quests, :only => [:active, :index, :unachieved] do
      collection do
        get :active
        get :unachieved
      end
    end

    resources :notes

    resources :bulk_ticket_actions do
      collection do
        post :update_multiple
      end
    end

    resources :merge_tickets do
      collection do
        post :complete_merge
        post :merge
        post :bulk_merge
      end
    end


    resources :ca_folders

    get 'canned_responses/folders(.:format)' => 'canned_responses/folders#index',
      as: :folders_canned_responses
    get 'canned_responses/folders/:folder_id/responses/new' => 'canned_responses/responses#new',
      as: :new_canned_responses_folder_response
    get 'canned_responses/folders/:id(.:format)' => 'canned_responses/folders#show',
      as: :show_canned_responses_folder
    put 'canned_responses/folders/:folder_id/responses/update_folder(.:format)' => 'canned_responses/responses#update_folder',
      as: :canned_responses_folder_responses_update_folder
    get 'canned_responses/folders/:folder_id/responses/:id/edit(.:format)' => 'canned_responses/responses#edit',
      as: :edit_canned_responses_folder
    put 'canned_responses/folders/:folder_id/responses/:id(.:format)' => 'canned_responses/responses#update',
      as: :update_canned_responses_folder
    delete 'canned_responses/folders/:folder_id/responses/delete_multiple(.:format)' => 'canned_responses/responses#delete_multiple',
      as: :canned_responses_folder_responses_delete_multiple
    
    get 'canned_responses/folders/new' => 'canned_responses/folders#new',
      as: :canned_responses_folder_responses_new

    get 'canned_responses/folders/:folder_id/responses(.:format)' =>  'canned_responses/responses#index',
      as: :canned_responses
    post 'canned_responses/folders/:folder_id/responses(.:format)' => 'canned_responses/responses#create',
      as: :create_canned_responses

    resources :canned_responses do
      collection do
        get :search
        get :recent
      end
      # resources :folders do
      #   collection do
      #     get :edit
      #   end
      #   resources :responses do
      #     collection do
      #       delete :delete_multiple
      #       put :update_folder
      #     end
      #     member do
      #       get :delete_shared_attachments
      #       post :delete_shared_attachments
      #     end
      #   end
      # end
    end



    match 'canned_responses/show/:id'  => 'canned_responses#show'
    match 'canned_responses/index/:id' => 'canned_responses#index'
    match 'canned_responses/show'      => 'canned_responses#show'

    resources :reminders do
      member do
        put :complete
        put :restore
      end
    end

    resources :time_sheets do
      member do
        put :toggle_timer
      end
    end

    match '/tags/:id/*filters' => 'tags#show', :as => :filter_tag_tickets
    match '/tickets/filter/tags' => 'tags#index', :as => :filter_tickets
    match '/tickets/filter/:filter_name' => 'tickets#index', :as => :filter_view_default
    match '/tickets/view/:filter_key' => 'tickets#index', :as => :filter_view_custom
    match '/tickets/filter/requester/:requester_id' => 'tickets#index', :as => :requester_filter
    match '/tickets/filter/customer/:customer_id' => 'tickets#index', :as => :customer_filter
    match '/tickets/filter/company/:company_id' => 'tickets#index', :as => :company_filter
    match '/tickets/get_solution_detail/:id' => 'tickets#get_solution_detail'
    match '/tickets/filter/tags/:tag_id' => 'tickets#index', :as => :tag_filter
    match '/tickets/filter/reports/:report_type' => 'tickets#index', :as => :reports_filter
    match '/dashboard.:format' => 'dashboard#index', :as => :formatted_dashboard
    match '/dashboard/activity_list' => 'dashboard#activity_list'
    match '/dashboard/latest_activities' => 'dashboard#latest_activities'
    match '/dashboard/latest_summary' => 'dashboard#latest_summary'
    match '' => 'dashboard#index', :as => :dashboard
    match '/sales_manager' => 'dashboard#sales_manager'
    match '/agent_status' => 'dashboard#agent_status'

    # For mobile apps backward compatibility.
    match '/subscriptions' => 'subscriptions#index'
    match '/tickets/delete_forever/:id' => 'tickets#delete_forever'
    # Mobile apps routes end.

    #freshchat routes with helpdesk namespace - start
    match '/freshchat/visitor/:filter' => 'visitor#index', :as => :visitor
    match '/freshchat/chat/:filter' => 'visitor#index', :as => :chat_archive
    #freshchat routes with helpdesk namespace - end

    match '/sales_manager' => 'dashboard#sales_manager'
    match '/agent-status' => 'dashboard#agent_status'
    
    resources :articles do
      collection do
        get :autocomplete
      end
    end

    resources :attachments do
      member do
        delete :unlink_shared
        get :text_content
      end
    end

    namespace :facebook do
      namespace :helpdesk do
        resources :attachments, :only => [:show, :destroy]
      end
    end
    resources :cloud_files

    resources :sla_policies, :except => :show do
      collection do
        put :reorder
      end
      member do
        put :activate
      end
    end

    resources :autocomplete do
      collection do
        get :requester
        post :company
      end
    end
    
    match 'commons/group_agents/(:id)' => "commons#group_agents"

    
    resources :scenario_automations do
      member do 
        get :clone_rule
      end 
      collection do 
        get :search
        get :recent
        put :reorder
      end
    end
  end

  #match '/helpdesk/canned_responses/index/:id' => 'helpdesk/canned_responses#index'

  match '/helpdesk/tickets/quick_assign/:id' => "Helpdesk::tickets#quick_assign", :as => :quick_assign_helpdesk_tickets,
    :method => :put

  resources :api_webhooks, :path => 'webhooks/subscription'

  namespace :solution do
    resources :categories do
      collection do
        put :reorder
      end

      resources :folders do
        collection do
          put :reorder
        end

        resources :articles do
          collection do
            put :reorder
          end

          member do
            put :thumbs_up
            put :thumbs_down
            post :delete_tag
            delete :destroy
          end
          resources :tag_uses
        end
      end
    end

    resources :articles, :only => [:show, :create, :destroy]
  end

  resources :posts, :as => 'all' do
    collection do
      get :search
    end
  end

  resources :topics
  resources :posts
  resources :monitorship


  namespace :discussions do
    resources :forums, :except => :index do
      collection do
        put :reorder
      end
    end

    match '/topics/:id/page/:page' => 'topics#show'
    match '/topics/:id/component/:name' => 'topics#component', :as => :topic_component

    resources :topics, :except => :index do
      collection do
        delete :destroy_multiple
      end
      member do
        put :toggle_lock
        get :latest_reply
        put :update_stamp
        put :remove_stamp
        put :vote
        delete :destroy_vote
        get :reply
      end

      resources :posts, :except => :new do
        member do
          put :toggle_answer
        end
      end

      match '/answer/:id' => 'posts#best_answer', :as => :best_answer
    end

    resources :moderation do
      collection do
        delete :empty_folder
        put :spam_multiple
      end

      member do
        put :approve
        put :ban
        put :mark_as_spam
        delete :delete_unpublished
      end
    end

    resources :unpublished do
      collection do
        delete :empty_folder
        put :spam_multiple
        get :more
      end
      member do
        put :approve
        put :ban
        put :mark_as_spam
        delete :delete_unpublished
        get :topic_spam_posts
        delete :empty_topic_spam
      end
    end

    match '/moderation/filter/:filter' => 'moderation#index', :as => :moderation_filter
    resources :merge_topic do 
      collection do  
        post :select
        put :review
        post :confirm
        put :merge
      end
    end
  end


  get 'discussions' => 'discussions#index', as: :discussions

  resources :discussions do
    collection do
      get :your_topics
      get :sidebar
      get :categories
      put :reorder
    end
  end

  resources :google_signup, :controller => 'google_signup' do
    collection do
      get :associate_local_to_google
      get :associate_google_account
    end
  end


  resources :posts

  resources :categories, :controller => 'forum_categories' do
    collection do
      put :reorder
    end

    resources :forums do
      collection do
        put :reorder
        post :create
        get :index
      end
      member do
        put :update
        get :show
        delete :destroy
      end

      resources :topics do
        collection do
          delete :destroy_multiple
        end
        member do
          get :users_voted
          put :update_stamp
          put :remove_stamp
          put :update_lock
        end
      end

      resources :topics do
        resources :posts do
          member do
            put :toggle_answer
          end
        end
        match '/answer/:id' => 'posts#best_answer', :as => :best_answer
      end
    end
  end

  match '/support/theme.:format' => 'theme/support#index'
  match '/support/theme_rtl.:format' => 'theme/support_rtl#index'
  match '/helpdesk/theme.:format' => 'theme/helpdesk#index'
  match "/facebook/theme.:format", :controller => 'theme/facebook', :action => :index
  match "/facebook/theme_rtl.:format", :controller => 'theme/facebook_rtl', :action => :index

  get 'discussions/:object/:id/subscriptions/is_following(.:format)', 
    :controller => 'monitorships', :action => 'is_following', 
    :as => :view_monitorship

  match 'discussions/:object/:id/subscriptions/:type(.:format)',
    :controller => 'monitorships', :action => 'toggle',
    :as => :toggle_monitorship



  namespace :support do
    match 'home' => 'home#index', :as => :home
    match 'preview' => 'preview#index', :as => :preview
    resource :login, :controller => "login", :only => [:new, :create]
    match '/login' => 'login#new'
    resource :signup, :only => [:new, :create]
    match '/signup' => 'signups#new'

    resource :profile, :only => [:edit, :update]
    resource :search, :controller => "search", :only => :show do
      member do
        get :solutions
        get :topics
        get :tickets
        get :suggest_topic
      end
      match '/topics/suggest', :action => 'suggest_topic'
      match '/articles/:article_id/related_articles', :action => 'related_articles'
    end

    resources :discussions, :only => [:index, :show] do
      collection do
        get :user_monitored
      end
    end

    namespace :discussions do
      resources :forums, :only => :show do
        member do
          put :toggle_monitor
        end
      end

      match '/forums/:id/:filter_topics_by' => 'forums#show', :as => :filter_topics
      match '/forums/:id/page/:page' => 'forums#show'

      match '/topics/my_topics/page/:page' => 'topics#my_topics'
      match '/topics/:id/page/:page' => 'topics#show'

      resources :topics, :except => :index do
        collection do
          get :my_topics
          get :reply
        end

        member do
          put :like
          get :hit
          put :unlike
          put :toggle_monitor
          put :monitor
          get :check_monitor
          get :users_voted
          put :toggle_solution
          get :reply
        end

        resources :posts, :except => [:index, :new, :show] do
          member do
            put :toggle_answer
          end
          collection do
            get :show
          end
        end

        match '/answer/:id' => 'posts#best_answer', :as => :best_answer
      end
    end


    resources :solutions, :only => [:index, :show]

    namespace :solutions do
      match '/folders/:id/page/:page' => 'folders#show'
      resources :folders, :only => :show

      resources :articles, :only => [:show, :destroy, :index] do
        member do
          put :thumbs_up
          put :thumbs_down
          post :create_ticket
          get :hit
        end
      end
    end

    resources :tickets do
      collection do
        get :check_email
        get :configure_export
        get :filter
        post :export_csv
      end

      member do
        post :close
        put :add_people
      end
      resources :notes
    end

    match '/surveys/:ticket_id' => 'surveys#create_for_portal', :as => :portal_survey
    match '/surveys/:survey_code/:rating/new' => 'surveys#new', :as => :customer_survey
    match '/surveys/:survey_code/:rating' => 'surveys#create', :as => :survey_feedback, :via => :post

    namespace :mobihelp do
      resources :tickets do
        member do
          post :notes
          post :close
        end
      end
    end
  end

  namespace :anonymous do
    resources :requests
  end

  namespace :public do
    resources :tickets do
      resources :notes
    end
  end

  namespace :mobile do
    resources :tickets do
      collection do
        get :view_list
        get :get_portal
        get :ticket_properties
        get :load_reply_emails
      end
    end

    resources :automations, :only => :index
    resources :notifications, :only => {} do
      collection do
        put :register_mobile_notification
      end
    end
    resources :settings,  :only => [:index] do
      collection do
        get :mobile_pre_loader
        get :deliver_activation_instructions
      end
    end
  end

  namespace :mobihelp do
    resources :devices do
      collection do
        post :register
        get :app_config
        post :register_user
      end
    end

    resources :solutions do
      collection do
        get :articles
      end
    end
  end

  namespace :notification do
    resources :product_notification, :only => :index
  end

  resources :rabbit_mq, :only => [:index]
  match '/marketplace/login' => 'google_login#marketplace_login', :as => :route
  match '/openid/google' => 'google_login#marketplace_login'
  match '/google/login' => 'google_login#portal_login', :as => :route
  match '/gadget/login', :controller => 'google_login', :action => 'google_gadget_login', :as => :route
  match '/' => 'home#index'
  # match '/:controller(/:action(/:id))'
  match '/all_agents' => 'agents#list'
  match '/download_file/:source/:token', :controller => 'admin/data_export', :action => 'download', :method => :get
  match '/freshchat/chatenable', :controller => 'chats', :action => 'chatEnable', :method => :post
  match '/freshchat/chattoggle', :controller => 'chats', :action => 'chatToggle', :method => :post
  match '/chat/agents', :controller => 'chats', :action => 'agents', :method => :get

  resources :chats do
    collection do
      post :create_ticket
      post :add_note
    end
  end

  #  constraints(lambda {|req| req.subdomain == AppConfig['partner_subdomain'] }) do
  namespace :partner_admin, :as => 'partner' do
    resources :affiliates do
      collection do
        post :add_affiliate_transaction
        post :add_reseller
        post :add_subscriptions_to_reseller
        get :fetch_affilate_subscriptions
        get :affiliate_subscription_summary
        get :fetch_reseller_account_info
        get :fetch_account_activity
        post :remove_reseller_subscription
      end
    end
  end
  #  end
  match '/marketplace/login', :controller => 'google_login', :action => 'marketplace_login'
  match '/gadget/login', :controller => 'google_login', :action => 'google_gadget_login'
  match '/google/login', :controller => 'google_login', :action => 'portal_login'

  constraints(lambda {|req| req.subdomain == AppConfig['billing_subdomain'] }) do
    # namespace :billing do
    resources :billing, :controller => 'billing/billing' do
      collection do
        post :trigger
      end
    end
    # end
  end

  constraints(lambda {|req| req.subdomain == AppConfig['freshops_subdomain'] })  do 
    namespace :fdadmin, :name_prefix => "fdadmin_", :path_prefix => nil do
      resources :subscriptions, :only => [:none] do
        collection do
          get :display_subscribers
        end
      end

      resources :accounts, :only => :show do
        collection do
          put :add_day_passes
          put :add_feature
          put :change_url
          get :single_sign_on
        end
      end
    end
  end


  # match ':controller(/:action(/:id))', :via => :all
  # match ':controller/:action/(:id).:format', :via => :all
  #SAAS copy starts here
  # map.with_options(:conditions => {:subdomain => AppConfig['admin_subdomain']}) do |subdom|
  #   subdom.root :controller => 'subscription_admin/subscriptions', :action => 'index'
  #   subdom.with_options(:namespace => 'subscription_admin/', :name_prefix => 'admin_', :path_prefix => nil) do |admin|
  #     admin.resources :subscriptions, :collection => {:customers => :get, :deleted_customers => :get, :customers_csv => :get}
  #     admin.resources :accounts,:member => {:add_day_passes => :post}, :collection => {:agents => :get, :tickets => :get, :renewal_csv => :get }
  #     admin.resources :subscription_plans, :as => 'plans'
  #     # admin.resources :subscription_discounts, :as => 'discounts'
  #     admin.resources :subscription_affiliates, :as => 'affiliates', :collection => { :add_affiliate_transaction => :post },
  #                                               :member => { :add_subscription => :post }
  #     admin.resources :subscription_payments, :as => 'payments'
  #     admin.resources :subscription_announcements, :as => 'announcements'
  #     admin.resources :conversion_metrics, :as => 'metrics'
  #     admin.resources :account_tools, :as => 'tools', :collection =>{:regenerate_reports_data => :post, :update_global_blacklist_ips => :put }
  #     admin.resources :manage_users, :as => 'manage_users', :collection =>{:add_whitelisted_user_id => :post, :remove_whitelisted_user_id => :post }
  #     admin.namespace :resque do |resque|
  #       resque.home '', :controller => 'home', :action => 'index'
  #       resque.failed_show '/failed/:queue_name/show', :controller => 'failed', :action => 'show'
  #       resque.resources :failed, :member => { :destroy => :delete , :requeue => :put }, :collection => { :destroy_all => :delete, :requeue_all => :put }
  #     end

  #     admin.freshfone '/freshfone_admin', :controller => :freshfone_subscriptions, :action => :index
  #     admin.freshfone_stats '/freshfone_admin/stats', :controller => :freshfone_stats, :action => :index

  #     # admin.resources :analytics
  #     admin.resources :spam_watch, :only => :index
  #     admin.spam_details ':shard_name/spam_watch/:user_id/:type', :controller => :spam_watch, :action => :spam_details
  #     admin.spam_user ':shard_name/spam_user/:user_id', :controller => :spam_watch, :action => :spam_user
  #     admin.block_user ':shard_name/block_user/:user_id', :controller => :spam_watch, :action => :block_user
  #     admin.hard_block_user ':shard_name/hard_block/:user_id', :controller => :spam_watch, :action => :hard_block
  #     admin.internal_whitelist ':shard_name/internal_whitelist/:user_id', :controller => :spam_watch, :action => :internal_whitelist
  #     admin.resources :subscription_events, :as => 'events', :collection => { :export_to_csv => :get }
  #     admin.resources :custom_ssl, :as => 'customssl', :collection => { :enable_custom_ssl => :post }
  #     admin.resources :currencies, :as => 'currency'
  #     admin.subscription_logout 'admin_sessions/logout', :controller => :admin_sessions , :action => :destroy
  #     admin.subscription_login 'admin_sessions/login', :controller => :admin_sessions , :action => :new
  #     admin.resources :subscription_users, :as => 'subscription_users', :member => { :update => :post, :edit => :get, :show => :get }, :collection => {:reset_password => :get }
  #   end
  # end

  # map.with_options(:conditions => {:subdomain => AppConfig['partner_subdomain']}) do |subdom|
  #   subdom.with_options(:namespace => 'partner_admin/', :name_prefix => 'partner_', :path_prefix => nil) do |partner|
  #     partner.resources :affiliates, :collection => {:add_affiliate_transaction => :post}
  #   end
  # end

  # map.with_options(:conditions => { :subdomain => AppConfig['billing_subdomain'] }) do |subdom|
  #   subdom.with_options(:namespace => 'billing/', :path_prefix => nil) do |billing|
  #     billing.resources :billing, :collection => { :trigger => :post }
  #   end
  # end
  match '/freshchat/create_ticket', :controller => 'chats', :action => 'create_ticket', :method => :post
  match '/freshchat/add_note', :controller => 'chats', :action => 'add_note', :method => :post
  match '/freshchat/chat_note', :controller => 'chats', :action => 'chat_note', :method => :post

  match '/freshchat/activate', :controller => 'chats', :action => 'activate', :method => :post

  match '/freshchat/site_toggle', :controller => 'chats', :action => 'site_toggle', :method => :post

  match '/freshchat/widget_toggle', :controller => 'chats', :action => 'widget_toggle', :method => :post
  match '/freshchat/widget_activate', :controller => 'chats', :action => 'widget_activate', :method => :post

  match '/freshchat/agents', :controller => 'chats', :action => 'agents', :method => :get

end
