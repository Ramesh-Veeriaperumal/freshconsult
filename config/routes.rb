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

  match '/health_checkup' => 'health_checkup#app_health_check',via: :get

  constraints(lambda {|req| req.subdomain == AppConfig['admin_subdomain'] }) do

    namespace :subscription_admin, :as => 'admin' do
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
      # resources :conversion_metrics, :as => 'metrics'

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

      # resources :currencies, :as => 'currency'

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

  # Constraint based routing to V2 paths
  #
  constraints Search::V1Path::MobilePath.new do
    match '/helpdesk/authorizations/autocomplete',            to: 'search/v2/mobile/autocomplete#autocomplete_requesters',        via: :get
    match '/helpdesk/authorizations/company_autocomplete',    to: 'search/v2/mobile/autocomplete#companies',         via: :get
    match '/helpdesk/autocomplete/requester',                 to: 'search/v2/mobile/autocomplete#requesters', via: :get
    match '/helpdesk/autocomplete/agents',                    to: 'search/v2/mobile/autocomplete#agents',            via: :get
    match '/helpdesk/autocomplete/companies',                 to: 'search/v2/mobile/autocomplete#companies',         via: :get
    match '/search/autocomplete/tags',                        to: 'search/v2/mobile/autocomplete#tags',              via: :get
    match '/search/home',                                     to: 'search/v2/mobile/suggest#index',           via: :get
    match '/search/tickets/filter/:search_field',             to: 'search/v2/mobile/merge_tickets#index',     via: :post
    match '/mobile/tickets/get_suggested_solutions/:ticket.:format',  to: 'search/v2/mobile/related_articles#index',  via: :get
  end
  #
  constraints Search::V1Path::WebPath.new do
    # Web paths
    match '/search/home/suggest',              to: 'search/v2/suggest#index',                    via: :get
    match '/search/all',                       to: 'search/v2/spotlight#all',                    via: :get
    match '/search/tickets',                   to: 'search/v2/spotlight#tickets',                via: :get
    match '/search/customers',                 to: 'search/v2/spotlight#customers',              via: :get
    match '/search/forums',                    to: 'search/v2/spotlight#forums',                 via: :get
    match '/search/solutions',                 to: 'search/v2/spotlight#solutions',              via: :get
    match '/search/autocomplete/requesters',   to: 'search/v2/autocomplete#requesters',          via: :get
    match '/search/autocomplete/agents',       to: 'search/v2/autocomplete#agents',              via: :get
    match '/search/autocomplete/companies',    to: 'search/v2/autocomplete#companies',           via: :get
    match '/search/autocomplete/company_users',    to: 'search/v2/autocomplete#company_users',           via: :get
    match '/search/autocomplete/tags',         to: 'search/v2/autocomplete#tags',                via: :get
    match '/search/merge_topic',               to: 'search/v2/merge_topics#search_topics',       via: :post
    match '/contact_merge/search',             to: 'search/v2/merge_contacts#index',             via: :get

    match '/search/tickets', to: 'search/v2/spotlight#tickets', via: :post

    match '/search/related_solutions/ticket/:ticket', to: 'search/v2/solutions#related_solutions',  via: :get, constraints: { format: /(html|js)/ }
    match '/search/search_solutions/ticket/:ticket',  to: 'search/v2/solutions#search_solutions',   via: :get, constraints: { format: /(html|js)/ }
    match '/search/tickets/filter/:search_field',     to: 'search/v2/tickets#index',                via: :post

    # Linked ticket routes
    match '/search/ticket_associations/filter/:search_field', to: 'search/v2/ticket_associations#index'
    match '/search/ticket_associations/recent_trackers',      to: 'search/v2/ticket_associations#recent_trackers', via: :post

    match '/support/search',                   to: 'support/search_v2/spotlight#all',               via: :get
    match '/support/search/tickets',           to: 'support/search_v2/spotlight#tickets',           via: :get
    match '/support/search/topics',            to: 'support/search_v2/spotlight#topics',            via: :get
    match '/support/search/solutions',         to: 'support/search_v2/spotlight#solutions',         via: :get
    match '/support/search/topics/suggest',    to: 'support/search_v2/spotlight#suggest_topic',     via: :get

    match 'support/search/articles/:article_id/related_articles', to: 'support/search_v2/solutions#related_articles', via: :get

    # Freshfone paths
    match '/freshfone/autocomplete/requester_search', to: 'search/v2/freshfone/autocomplete#contact_by_numbers',  via: :get
    match '/freshfone/autocomplete/customer_phone_number', to: 'search/v2/freshfone/autocomplete#customer_by_phone',  via: :get
    match '/freshfone/autocomplete/customer_contact', to: 'search/v2/freshfone/autocomplete#contact_by_numberfields',  via: :get
  end

  root :to => 'home#index'

  get '/a/*others', to: 'home#index_html'
  get '/a/', to: 'home#index_html'
  match "/support/sitemap" => "support#sitemap", :format => "xml", :as => :sitemap, :via => :get
  match "/robots" => "support#robots", :format => "text", :as => :robots, :via => :get

  match '/visitor/load/:id.:format' => 'chats#load', :via => :get
  match '/images/helpdesk/attachments/:id(/:style(.:format))' => 'helpdesk/attachments#show', :via => :get
  match '/inline/attachment' => 'helpdesk/inline_attachments#one_hop_url', :via => :get
  match '/javascripts/:action.:format' => 'javascripts#index'
  match '/packages/:package.:extension' => 'jammit#package', :as => :jammit, :constraints => { :extension => /.+/ }
  resources :authorizations

  Integrations::Constants::INTEGRATION_ROUTES.each do |provider|
    match "/auth/#{provider}/callback" => 'omniauth_callbacks#complete', :provider => provider
  end

  match "/auth/gmail/callback" => 'omniauth_callbacks#complete', :provider => 'gmail'
  match "/auth/gmail/failure" => 'omniauth_callbacks#failure', :as => :failure

  match '/shopify_integration_redirect' => 'shopify_listing#send_approval_request', :via => :get
  match '/shopify_landing' => 'shopify_listing#show', :via => :get
  match '/shopify_account_verification' => 'shopify_listing#verify_domain_shopify', :via => :post
  match '/auth/:provider/callback' => 'authorizations#create', :as => :callback
  match '/oauth2callback' => 'authorizations#create', :as => :calender, :provider => 'google_oauth2'
  match '/auth/failure' => 'authorizations#failure', :as => :failure
  match "/facebook/page/callback" => 'facebook_redirect_auth#complete'
  match "/twitter/handle/callback" => 'twitter_redirect_auth#complete'
  match '/simple_outreach_unsubscribe_status' => 'external_action#unsubscribe', :via => :get
  match '/simple_outreach_unsubscribe' => 'external_action#email_unsubscribe', :via => :post

  resources :solutions_uploaded_images, :only => [:index, :create]  do
    collection do
      post :delete_file
      post :create_file
    end
  end

  resources :forums_uploaded_images, :only => [:index, :create] do
    collection do
      post :delete_file
      post :create_file
    end
  end

  resources :tickets_uploaded_images, :only => :create do
    collection do
      post :create_file
    end
  end

  resources :ticket_templates_uploaded_images, :only => :create do
    collection do
      post :create_file
    end
  end

  resources :email_notification_uploaded_images, :only => :create do
    collection do
      post :create_file
    end
  end

  resources :email_preview do
    collection do
      post :generate_preview
      post :send_test_email
    end
  end

  # contacts and companies import
  resources :customers_import do
    collection do
      post :create
    end
  end
  match '/imports/:type' => 'customers_import#csv'
  match '/imports/:type/map_fields' => 'customers_import#map_fields'

  namespace :health_check do
    get :verify_domain
    get :verify_credential
  end

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
      get :component
    end
    collection do
      delete :destroy
      post :quick
      post :create_company
      get :configure_export
      post :export_csv
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
      get :configure_export
      post :export_csv
      get :contact_details_for_ticket
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
      get :change_password
      put :update_password
      get :unblock
      post :create_contact
      put :update_contact
      put :update_description_and_tags
      get :view_conversations
    end
  end

  # segment/group controller will handle all different types in request params # content based routing
  match '/integrations/segment' => 'segment/identify#create', :constraints => lambda{|req| req.request_parameters["type"] == "identify"}
  match '/integrations/segment' => 'segment/group#create', :constraints => lambda{|req| req.request_parameters["type"] != "identify"}

  match '/contacts/filter/:state(/*letter)' => 'contacts#index', :format => false
  resources :groups do
    collection do
      get  :index
      get  :enable_roundrobin_v2
    end
    member do
      get :user_skill_exists
    end
  end

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
      put :notification_read
      put :on_boarding_complete
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
      get :configure_export
      post :export_csv
      post :export_skill_csv
      get :search_in_freshworks
    end
    member do
      put :toggle_shortcuts
      put :restore
      get :convert_to_user
      put :reset_password
      put :convert_to_contact
      put :reset_score
      post :toggle_availability
      get :api_key
    end
    resources :time_sheets
  end

  match '/agents/filter/:state(/*letter)' => 'agents#index'
  match '/groups/filter/:state' => 'groups#index'
  match '/logout' => 'user_sessions#destroy', :as => :logout
  match '/login' => 'user_sessions#new', :as => :login
  match '/login/sso' => 'user_sessions#sso_login', :as => :sso_login
  match '/mobile_freshid_logout' => 'user_sessions#mobile_freshid_logout', :as => :mobile_freshid_logout
  match '/login/sso_v2' => 'user_sessions#jwt_sso_login', :as => :jwt_sso_login
  match '/login/saml' => 'user_sessions#saml_login', :as => :saml_login
  match '/login/normal' => 'user_sessions#new', :as => :login_normal
  match 'agent/login' => 'user_sessions#agent_login', :as => :agent_login
  match 'customer/login' => 'user_sessions#customer_login', :as => :customer_login
  match '/signup_complete/:token' => 'user_sessions#signup_complete', :as => :signup_complete
  match '/mobile/token' => 'user_sessions#mobile_token', via: :post
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
        get :trial_warnings
        post :external_transfer_success
        post :call_transfer_success
        get :caller_recent_tickets
      end
    end

    resources :conference do
      collection do
        get  :initiate
        post :wait
        post :agent_wait
        post :incoming_agent_wait
        post :outgoing_accepted
        post :pinged_agent_response
        post :connect_incoming_caller
        post :complete_customer_wait_conference
        post :client_accept
        post :connect_agent
      end
    end

    resources :agent_leg do
      collection do
        post :disconnect_browser_agent
        put :agent_response
        post :remove_notification_recovery
      end
    end

    resources :conference_transfer do
      collection do
        get  :initiate_transfer
        post :transfer_agent_wait
        get  :complete_transfer
        post :transfer_success
        post :transfer_source_redirect
        post :cancel_transfer
        post :resume_transfer
        get :disconnect_agent
      end
    end

    resources :warm_transfer do
      collection do
        post :initiate
        post :success
        post :status
        post :redirect_source_agent
        post :redirect_customer
        post :join_agent
        post :transfer_agent_wait
        post :unhold
        post :wait
        post :quit
        post :cancel
        post :resume
        post :initiate_custom_forward
        post :process_custom_forward
      end
    end

    resources :agent_conference do
      collection do
        post :add_agent
        post :success
        post :status
        post :cancel
        post :initiate_custom_forward
        post :process_custom_forward
      end
    end

    resources :hold do
      collection do
        get  :add
        get  :remove
        post :initiate
        post :wait
        post :unhold
        post :transfer_unhold
        post :transfer_fallback_unhold
        post :quit
      end
    end

    resources :forward do
      collection do
        post :initiate
        post :initiate_custom
        post :initiate_custom_transfer
        post :process_custom
        post :process_custom_transfer
        post :complete
        post :transfer_initiate
        post :transfer_complete
        post :transfer_wait
        post :direct_dial_wait
        post :direct_dial_accept
        post :direct_dial_connect
        post :direct_dial_success
        post :direct_dial_complete
      end
    end

    resources :conference_call do
      collection do
        post :status
        post :in_call
        post :update_recording
        post :save_notable
        put :wrap_call
        get :load_notable
        post :save_call_quality_metrics
      end
    end

    resources :queue do
      collection do
        post :enqueue
        post :dequeue
        post :quit_queue_on_voicemail
        post :trigger_voicemail
        post :trigger_non_availability
        post :hangup
        post :redirect_to_queue
      end
    end

    resources :voicemail do
      collection do
        post :quit_voicemail
        post :initiate
        post :transcribe
      end
    end

    resources :call_transfer do
      collection do
        get :initiate
        post :transfer_incoming_call
        post :transfer_outgoing_call
        post :transfer_incoming_to_group
        post :transfer_outgoing_to_group
        post :transfer_incoming_to_external
        post :transfer_outgoing_to_external
        get :available_agents
        get :available_external_numbers
      end
    end
    match '/call_transfer/initiate/' => 'call_transfer#initiate', :via => :post

    resources :device do
      collection do
        post :record
        get :recorded_greeting
      end
    end

    resources :caller do
      collection do
        post :block
        post :unblock
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
        post :manage_presence
      end
    end

    resources :autocomplete do
      collection do
        get :requester_search
        get :customer_phone_number
        get :customer_contact
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

    resources :address do
      member do
        post :create
      end
      collection do
        get :inspect
      end
    end
  end

  resources :freshfone do
    collection do
      post :voice
      post :build_ticket
      get :dashboard_stats
      get :get_available_agents
      post :ivr_flow
      post :voice_fallback
      post :create_note
      post :create_ticket
      get :dial_check
    end
  end

  match '/freshfone/preview_ivr/:id' => 'freshfone#preview_ivr', :via => :post

  namespace :freshfone, :path => "phone" do
    resources :call_history do
      member do
        delete :destroy_recording
      end
      collection do
        get :custom_search
        get :children
        get :recent_calls
        get :export
      end
    end
  end

  match '/freshfone/call_history/custom_search' => 'freshfone/call_history#custom_search'
  match '/freshfone/call_history/children' => 'freshfone/call_history#children'

  namespace :freshfone, :path => "phone" do
    resources :dashboard do
      collection do
        get :dashboard_stats
        get :calls_limit_notificaiton
        post :mute
      end
    end
  end

  namespace :freshfone, :path => "phone" do
    resources :caller_id do
      collection do
        post :validation
        post :verify
        post :add
        post :delete
      end
    end
  end

  resources :users do
    collection do
      get :revert_identity
      get :assumable_agents
      put :accept_gdpr_compliance
    end
    member do
      delete :delete_avatar
      put :block
      get :assume_identity
      get :profile_image
      get :profile_image_no_blank
    end
  end

  resource :user_session

  match '/enable_falcon_for_all' => 'users#enable_falcon_for_all', :as => :enable_falcon_for_all, via: :post
  match '/disable_old_helpdesk' => 'users#disable_old_helpdesk', :as => :disable_old_helpdesk, via: :post

  match '/enable_falcon' => 'users#enable_falcon', :as => :enable_falcon, via: :post
  match '/disable_falcon' => 'users#disable_falcon', :as => :disable_falcon, via: :post
  match '/enable_undo_send' => 'users#enable_undo_send', :as => :enable_undo_send, via: :post
  match '/disable_undo_send' => 'users#disable_undo_send', :as => :disable_undo_send, via: :post
  match '/change_focus_mode' => 'users#change_focus_mode', :as => :change_focus_mode, via: :post
  match '/set_notes_order' => 'users#set_conversation_preference', :as => :set_notes_order, via: :put
  match '/enable_skip_mandatory' => 'admin/account_additional_settings#enable_skip_mandatory', :as => :enable_skip_mandatory, via: :post
  match '/disable_skip_mandatory' => 'admin/account_additional_settings#disable_skip_mandatory', :as => :disable_skip_mandatory, via: :post
  match '/register/:activation_code' => 'activations#new', :as => :register
  match 'register_new_email/:activation_code' => 'activations#new_email', :as => :register_new_email
  match '/activate/:perishable_token' => 'activations#create', :as => :activate
  match '/set_notes_order' => 'users#set_conversation_preference', :as => :set_notes_order, via: :put

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
  resources :mime, :only => [:new, :create]
  resources :email_service, :only =>[:new, :create]
  resources :mailgun, :only => :create
  post '/mailgun/create', to: "mailgun#create"
  resources :password_resets, :except => [:index, :show, :destroy]

  resources :sso do
    collection do
      get :login
      get :facebook
      get :twitter
      get :portal_google_sso
      get :marketplace_google_sso
      get :mobile_freshid_login
      get :mobile_freshid_logout
      post :mobile_sso_login
    end
  end

  resource :account_configuration

  namespace :integrations do

    match '/service_proxy/fetch',
      :controller => 'service_proxy', :action => 'fetch', :via => :post

    resources :installed_applications do
      member do
        put :install
        delete :uninstall
      end
    end

    namespace :salesforce do
        put :update
        get :edit
        get :new
        post :install
    end

    namespace :cloud_elements, :path => "sync" do
      namespace :crm do
        get :settings
        post :create
        get :instances
        get :edit
        post :update
        post :fetch
      end
    end

    resources :remote_configurations

    namespace :github do
        put :update
        get :edit
        get :new
        get :oauth_install
        post :install
        post :notify
    end

    namespace :slack_v2 do
      get :oauth
      get :new
      post :install
      get :edit
      get :add_slack_agent
      put :update
      post :help
      post :create_ticket
      post :tkt_create_v3
    end

    namespace :microsoft_teams, :path => "teams" do
      get :oauth
      get :install
      get :authorize_agent
    end

    namespace :google_hangout_chat, :path => "google_hangout_chat" do
      get :oauth
      get :install
    end

    resources :applications, :only => [:index, :show] do
      collection do
        post :oauth_install
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

    resources :google_accounts, :only => [:new, :update, :delete] do
      member do
        delete :delete
      end
      collection do
        get :new
        put :update
      end
    end

    namespace :gmail_gadget do
      get :spec
      get :open_social_auth
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

    resources :slack do #Belongs to Old Slack
      collection do
        post :create_ticket
      end
    end

    resources :user_credentials do
      collection do
        post :oauth_install
      end
    end

    resources :logmein do
      collection do
        post :rescue_session
        get :rescue_session
        put :update_pincode
        get :refresh_session
        get :tech_console
        get :authcode
      end
    end

    namespace :cti_admin do
      get :edit
      put :update
      post :add_phone_numbers
      get :unused_numbers
      delete :delete_number
    end
    namespace :cti do
      resources :customer_details do
        collection do
          get :fetch
          post :create_note
          post :create_ticket
          post :verify_session
          get :ameyo_session
        end
      end
      namespace :screen_pop do
        get :contact_details
        get :recent_tickets
        post :link_to_existing
        post :link_to_new
        post :add_note_to_new
        post :ignore_call
        post :set_pop_open
        get :phone_numbers
        post :set_phone_number
        post :click_to_dial
        get :ongoing_call
      end
    end

    resources :box do
      collection do
        get :choose
      end
    end

    namespace :quickbooks do
      post :refresh_access_token
      get :render_success
      post :create_company
      get :uninstall
    end

    namespace :outlook_contacts do
      get :settings
      get :edit
      post :install
      delete :destroy
      put :update
      post :render_fields
      post :new
    end

    namespace :marketplace do
      namespace :login do
        get :login
        get :tryout
      end

      namespace :quickbooks_sso do
        get :open_id
        get :open_id_complete
        get :landing
      end

      namespace :shopify do
        get :signup
        get :landing
        put :install
        get :create
        get :edit
        post :receive_webhook
        delete :remove_store
        post :update
      end

      namespace :google do
        get :onboard
        get :home
        get :landing
      end

      namespace :signup do
        put :associate_account
        put :create_account
        put :associate_account_using_proxy
      end
    end

    namespace :dynamicscrm do
      post :settings_update
      get :edit
      post :fields_update
      post :widget_data
      get :settings
    end

    namespace :ilos do
      post :ticket_note
      post :forum_topic
      post :solution_article
      post :get_recorder_token
      get :popupbox
    end

    namespace :magento do
      get :new
      get :edit
      post :update
    end

    namespace :office365 do
      post :note
      post :priority
      post :status
      post :agent
    end

    namespace :sugarcrm do
      post :settings_update
      get :edit
      get :settings
      post :fields_update
      post :renew_session_id
      post :check_session_id
    end

    namespace :fullcontact do
      get :new
      post :callback
      get :edit
      post :update
    end

    namespace :xero do
      get :authorize
      post :update_params
      get :edit
      get :fetch
      get :render_accounts
      get :check_item_exists
      get :render_currency
      get :fetch_create_contacts
      get :get_invoice
      get :authdone
      get :install
      post :create_invoices
    end

    namespace :hootsuite do

      resources :tickets, :only => [:update,:create,:show] do
        collection do
          post :add_note
          post :twitter
          post :facebook
          post :add_reply
          get :full_text
          get :user_following
          get :group_agents
        end
      end

      namespace :home do
        get :domain_page
        post :plugin
        post :verify_domain
        get :handle_plugin
        delete :destroy
        get :destroy
        post :uninstall
        get :index
        get :refresh
        post :iframe_page
        post :search
        get :plugin_url
      end
    end

    namespace :onedrive do
      get :callback
      get :onedrive_render_application
      get :onedrive_view
    end

    namespace :infusionsoft do
      post :fetch_user
      post :fields_update
      get :edit
      get :install
    end

    namespace :freshsales do
      get :new
      post :settings_update
      post :install
      get :edit
      put :update
    end

    resources :marketplace_apps, only: [:edit, :clear_cache] do
      collection do
        post :clear_cache
      end
      member do
        post :install
        delete :uninstall
        get '/:installed_extension_id/app_status', to: 'marketplace_apps#app_status'
      end
    end

    match '/refresh_access_token/:app_name' => 'oauth_util#get_access_token', :as => :oauth_action
    match '/applications/oauth_install/:id' => 'applications#oauth_install', :as => :app_oauth_install
    match '/user_credentials/oauth_install/:id' => 'user_credentials#oauth_install', :as => :custom_install_user
    match 'install/:app' => 'oauth#authenticate', :as => :oauth
  end

  match '/http_request_proxy/fetch',
      :controller => 'http_request_proxy', :action => 'fetch', :as => :http_proxy
  match '/freshcaller_proxy',
       :controller => 'freshcaller_proxy', :action => 'fetch', :as => :freshcaller_proxy, :via => :post 
  match '/freshcaller_proxy/recording_url', 
       :controller => 'freshcaller_proxy', :action => 'recording_url', :as => :freshcaller_proxy, :via => :get
  match '/mkp/data-pipe.:format', :controller => 'integrations/data_pipe', :action => 'router', :method => :post, :as => :data_pipe

  constraints RouteConstraints::Freshcaller.new do
    match '/admin/phone/redirect_to_freshcaller', controller: 'admin/freshcaller', action: 'redirect_to_freshcaller'
    match '/admin/phone', controller: 'admin/freshcaller', action: 'index'
    match '/admin/phone/*a', controller: 'admin/freshcaller', action: 'index'
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

    resources :requester_widget, :only => [:get_widget, :update_widget] do
      collection do
        get :get_widget
        put :update_widget
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
        get '/custom_filter', :action => :day_pass_history_filter
      end
    end

    resources :dkim_configurations, path: 'email_configs/dkim' do
      member do
        post :create
        get :verify_email_domain
        post :remove_dkim_config
      end
    end

    resources :widget_config, :only => :index
    resources :chat_widgets do
      collection do
         post :enable
         post :toggle
         put :update
      end
    end

    resources :freshchat, :only => [:index, :create, :update, :signup] do
      collection do
        put :toggle
        post :create
        put :update
        get :signup
      end
    end

    resources :skills do
      member do
        get :users
      end
      collection do
        put :reorder
        get :import
        post :process_csv
      end
    end

    match '/agent_skills/' => 'user_skills#index', :via => :get
    match '/agent_skills/:user_id' => 'user_skills#show', :via => :get
    match '/agent_skills/:user_id' => 'user_skills#update', :via => :put

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
        get :google_signin
        get :existing_email
        post :personalized_email_enable
        post :personalized_email_disable
        post :toggle_agent_forward_feature
        post :toggle_compose_email_feature
        post :reply_to_email_enable
        post :reply_to_email_disable
        post :id_less_tickets_enable
        post :id_less_tickets_disable
        post :validate_mailbox_details
      end
      member do
        put :make_primary
        put :deliver_verification
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
    resources :onboarding, only: [:index] do
      collection do
        post :update_channel_configs
        post :update_activation_email
        post :resend_activation_email
        post :complete_step
      end
    end

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
        post :export
      end
    end

    resources :products

    resources :portal, :only => [:index, :update, :edit, :create, :destroy] do

      collection do
        get :settings
        get :enable
        put :update_settings
      end
      member do
        delete :delete_logo
        delete :delete_favicon
      end

      resource :template do
        collection do
          get :show
          put :update
          put :soft_reset
          put :restore_default
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

    resources :surveys
    resources :custom_surveys do
      member do
        post :test_survey
      end
    end
    match '/surveys/update' => 'surveys#update' , :via => :put
    match '/surveys/enable/' => 'surveys#enable' , :via => :post
    match '/surveys/disable/' => 'surveys#disable' , :via => :post

    match '/custom_surveys/activate/:id' => 'custom_surveys#activate' , :via => :post
    match '/custom_surveys/deactivate/:id' => 'custom_surveys#deactivate' , :via => :post

    resources :gamification do
      collection do
        post :toggle
        get :quests
        put :update_game
        put :reset_arcade
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

    resources :freshfone, :only => [:index], :path => 'phone' do
      collection do
        get :search
        put :toggle_freshfone
        get :available_numbers
        post :request_freshfone_feature
      end
    end
    namespace :freshcaller, :path => 'freshcaller' do
      resources :signup do
        collection do
          post :link
        end
      end
    end

    namespace :freshfone, :path => 'phone' do
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

    resources :roles do
      collection do
        get :profile_image
        get :users_list
        post :update_agents
      end
    end

    namespace :social do
      resources :streams, :only => :index do
        collection do
          get :authorize_url
        end
      end
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
          put :activate
        end
      end
    end

    resources :mailboxes

    namespace :ecommerce do
      resources :accounts
      resources :ebay_accounts, :controller => 'ebay_accounts' do
        collection do
          post :generate_session
          get :authorize
          get :enable
          get :failure
        end
        member do
          get :renew_token
        end
      end
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

    # Marketplace
    namespace :marketplace do
      get :apps, only: [:index], controller: 'apps', action: [:index]

      resources :extensions, :only => [:index] do
        collection do
          get :custom_apps
          get :search
          get :auto_suggest
          get '/:extension_id', :action => :show, :as => 'show'
          scope '/:extension_id' do
            get :payment_info
          end
        end
      end

      namespace :installed_extensions do
        scope ':extension_id/:version_id' do
          get :new_configs
          get :edit_configs
          get :oauth_callback
          get :edit_oauth_configs
          get :iframe_configs
          get :oauth_install
          get :new_oauth_iparams
          get :edit_oauth_iparams
        end
        scope ':extension_id' do
          post :install
          put :reinstall
          delete :uninstall
          put :enable
          put :disable
          put :update_config
        end
        scope ':installed_extension_id' do
          get :app_status
        end
      end
    end

    namespace :integrations do
      resources :freshplugs, :except => [:index, :show] do
        member do
          put :enable
          put :disable
        end
        collection do
          post :custom_widget_preview
        end
      end
    end

  end

  match '/ecommerce/ebay_notifications', :controller => 'admin/ecommerce/ebay_accounts', :action => 'notify', :method => :post

  namespace :search do

    # Search v2 agent controller routes
    #
    namespace :v2 do
      resources :spotlight, :only => [:all, :tickets, :customers] do
        collection do
          get :all
          get :tickets
          get :customers
          get :forums
          get :solutions
        end
      end
      resources :suggest, :only => :index
      resources :autocomplete, :only => [:agents, :requesters, :companies, :tags] do
        collection do
          get :agents
          get :requesters
          get :companies
          get :tags
          get :company_users
        end
      end
      resources :tickets, :only => :index
      resources :solutions, :only => [:related_solutions, :search_solutions]
      resources :merge_topics, :only => [:search_topics] do
        collection do
          post :search_topics
        end
      end
      resources :merge_contacts, :only => :index

      # Paths for mobile search v2
      namespace :mobile do
        resources :suggest, only: :index
        resources :merge_tickets, only: :index
        resources :related_articles, only: :index
        resources :autocomplete, only: [:agents, :requesters, :companies, :tags] do
          collection do
            get :agents
            get :requesters
            get :companies
            get :tags
          end
        end
      end

      namespace :freshfone do
        resources :autocomplete, only: [:contact_by_numbers, :customer_by_phone, :contact_by_numberfields] do
          collection do
            get :contact_by_numbers
            get :customer_by_phone
            get :contact_by_numberfields
          end
        end
      end

      resources :ticket_associations, :only => [:index, :recent_trackers]
    end

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
        get :company_users
      end
    end

    resources :tickets, :only => :index
    resources :solutions, :only => :index
    resources :forums, :only => :index
    resources :customers, :only => :index
    match '/related_solutions/ticket/:ticket/' => 'solutions#related_solutions', :as => :ticket_related_solutions
    match '/search_solutions/ticket/:ticket/' => 'solutions#search_solutions', :as => :ticket_search_solutions
  end

  match '/search/tickets' => 'search/tickets#index', via: [:get, :post]
  match '/search/tickets/filter/:search_field' => 'search/tickets#index'
  match '/search/ticket_associations/filter/:search_field' => 'search/ticket_associations#index'
  match '/search/ticket_associations/recent_trackers' => 'search/ticket_associations#index', via: :post
  match '/search/all' => 'search/home#index'
  match '/search/home' => 'search/home#index', :as => :search_home
  match '/search/topics.:format' => 'search/forums#index'
  match '/mobile/tickets/get_suggested_solutions/:ticket.:format' => 'search/solutions#related_solutions'
  match '/search/merge_topic', :controller => 'search/merge_topic', :action => 'index'
  match '/search/recent_searches_tickets' => 'search/home#recent_searches_tickets', :method => :get
  match '/search/remove_recent_search' => 'search/home#remove_recent_search', :method => :post
  # routes for custom survey reports
  match '/reports/custom_survey' => 'reports/custom_survey_reports#index', :as => :custom_survey_activity
  match '/analytics/custom_survey' => 'reports/custom_survey_reports#index', :as => :custom_survey_analytics_activity
  match '/reports/custom_survey/aggregate_report/:survey_id/:group_id/:agent_id/:date_range' => 'reports/custom_survey_reports#aggregate_report', :as => :custom_survey_aggregate_report
  match '/reports/custom_survey/group_wise_report/:survey_id/:group_id/:agent_id/:survey_question_id/:date_range' => 'reports/custom_survey_reports#group_wise_report', :as => :custom_survey_group_wise_report
  match '/reports/custom_survey/agent_wise_report/:survey_id/:group_id/:agent_id/:survey_question_id/:date_range' => 'reports/custom_survey_reports#agent_wise_report', :as => :custom_survey_agent_wise_report
  match '/reports/custom_survey/responses/:survey_id/:group_id/:agent_id/:survey_question_id/:rating/:date_range' => 'reports/custom_survey_reports#remarks', :as => :custom_survey_remarks
  match '/reports/custom_survey/save_reports_filter' =>  'reports/custom_survey_reports#save_reports_filter', :as => :custom_survey_save_reports_filter
  match '/reports/custom_survey/update_reports_filter' =>  'reports/custom_survey_reports#update_reports_filter', :as => :custom_survey_update_reports_filter
  match '/reports/custom_survey/delete_reports_filter' =>  'reports/custom_survey_reports#delete_reports_filter', :as => :custom_survey_delete_reports_filter
  match '/reports/custom_survey/export_csv' => 'reports/custom_survey_reports#export_csv'

  match '/analytics/custom_survey/aggregate_report/:survey_id/:group_id/:agent_id/:date_range' => 'reports/custom_survey_reports#aggregate_report', :as => :custom_survey_analytics_aggregate_report
  match '/analytics/custom_survey/group_wise_report/:survey_id/:group_id/:agent_id/:survey_question_id/:date_range' => 'reports/custom_survey_reports#group_wise_report', :as => :custom_survey_analytics_group_wise_report
  match '/analytics/custom_survey/agent_wise_report/:survey_id/:group_id/:agent_id/:survey_question_id/:date_range' => 'reports/custom_survey_reports#agent_wise_report', :as => :custom_survey_analytics_agent_wise_report
  match '/analytics/custom_survey/responses/:survey_id/:group_id/:agent_id/:survey_question_id/:rating/:date_range' => 'reports/custom_survey_reports#remarks', :as => :custom_survey_analytics_remarks
  match '/analytics/custom_survey/save_reports_filter' =>  'reports/custom_survey_reports#save_reports_filter', :as => :custom_survey_save_analytics_reports_filter
  match '/analytics/custom_survey/update_reports_filter' =>  'reports/custom_survey_reports#update_reports_filter', :as => :custom_survey_update_analytics_reports_filter
  match '/analytics/custom_survey/delete_reports_filter' =>  'reports/custom_survey_reports#delete_reports_filter', :as => :custom_survey_delete_analytics_reports_filter
  match '/analytics/custom_survey/export_csv' => 'reports/custom_survey_reports#export_csv'

  # Keep this below search to override contact_merge_search_path
  #
  resources :contact_merge do
    collection do
      get :search
      post :new
      post :confirm
      post :merge
    end
  end

  #to support old path for timesheet_reports
  #old path : hostname/timesheet_reports
  #new path structure : hostname/reports/timesheet
  match "/timesheet_reports", :controller => 'reports/timesheet_reports', :action => 'index', :method => :get

  #Routes related to Reports
  namespace :reports do

    match '', action: :index, method: :get

    # 'timesheet' resource must be placed before new reports path, else it matches to v2/reports_controller
    # timesheet report uses reports/timesheet_reports_controller
    # both timesheet and new reports share the same path structure
    # path : reports/timesheet
    resource :timesheet, :controller => 'timesheet_reports' do
      collection do
        get  :index
        post :report_filter
        post :export_csv
        post :generate_pdf
        post :export_pdf
        post :save_reports_filter
        post :update_reports_filter
        post :delete_reports_filter
        post :time_entries_list
      end
    end

    resources :scheduled_exports, only: [:index] do
      collection do
        get :activities, action: :edit_activity
        post :activities, action: :update_activity
      end
    end

    resources :scheduled_exports, only: [:index, :new, :create, :show, :destroy] do
      get :clone_schedule, path: '/clone_schedule', on: :member
      get :download_file, path: '/download_file(/:file_name)', on: :member
    end
    #routes for v1 agent and group performance reports
    # match '/:id' , action: :show, method: :get, constraints: { id: /[1-2]+/ }
    match '/classic/:report_type', action: :show, method: :get
    match '/classic/:report_type', action: :show, method: :get

    #must be placed after 'timesheet' resource, to avoid path mismatch for timesheet report
    #both timesheet and new reports share the same path structure
    #path : reports/:report_type
    resource only: [], path: '(:ver)/:report_type', constraints: {ver: /v2/}, controller: 'v2/tickets/reports' do
      collection do
        get  :index
        get  :configure_export
        post :fetch_metrics
        post :fetch_active_metric
        post :fetch_ticket_list
        post :export_tickets
        post :export_report
        post :email_reports
        post :save_reports_filter
        post :delete_reports_filter
        post :update_reports_filter
        post :fetch
        post :fetch_qna_metric
        post :fetch_insights_metric
        post :save_insights_config
        post :fetch_recent_questions
        post :fetch_insights_config
        post :fetch_threshold_value
      end
    end

    get :download_file, path: '(:ver)/download_file/:report_export/:type/:date/:file_name', constraints: {ver: /v2/}, controller: 'v2/tickets/reports'

    namespace :freshfone, :path => "phone" do
      resources :summary_reports, only: ['index'], :controller => 'summary_reports' do
        collection do
          post :generate
          post :export_csv
          post :save_reports_filter
          post :update_reports_filter
          post :delete_reports_filter
          post :export_pdf
        end
      end
    end

    namespace :freshchat do
      resources :summary_reports, only: ['index'], :controller => 'summary_reports' do
        collection do
          post :generate
          post :save_reports_filter
          post :update_reports_filter
          post :delete_reports_filter
          post :export_pdf
        end
      end
    end

    match 'schedule/download_file', format: 'json', controller: 'freshvisuals', action: :download_schedule_file, via: :get
  end

  match '/gamification/reports' => 'reports/gamification_reports#index', :as => :scoreboard_activity
  match '/survey/reports' => 'reports/survey_reports#index', :as => :survey_activity
  match '/survey/analytics' => 'reports/survey_reports#index', :as => :survey_analytics_activity
  match '/survey/reports/:category/:view' => 'reports/survey_reports#index', :as => :survey_back_to_list
  match '/survey/reports_list' => 'reports/survey_reports#list', :as => :survey_list
  match '/survey/report_details/:entity_id/:category' => 'reports/survey_reports#report_details', :as => :survey_detail_report
  match '/survey/overall_report/:category' => 'reports/survey_reports#report_details', :as => :survey_overall_report
  match '/reports/survey_reports/feedbacks' => 'reports/survey_reports#feedbacks', :as => :survey_feedbacks
  match '/reports/survey_reports/refresh_details' => 'reports/survey_reports#refresh_details', :as => :survey_refresh_details
  match '/survey/reports/:survey_id/:group_id/:agent_id/:date_range' => 'reports/survey_reports#reports', :as => :survey_reports
  match '/survey/reports/remarks/:survey_id/:group_id/:agent_id/:rating/:date_range' => 'reports/survey_reports#remarks', :as => :survey_remarks

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
        get :user_following
        post :user_following
      end
    end
  end

  namespace :widgets do
    resource :feedback_widget do
      member do
        get :jsonp_create
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
      delete :delete_logo
      delete :delete_favicon
      get :new_signup_free
      put :update_languages
    end
  end

  match '/admin/manage_languages' => 'accounts#manage_languages', :as => :manage_languages

  resource :accounts do
    collection do
      get :new_signup_free
      post :email_signup
      post :new_signup_free
      get :edit_domain
      put :update_domain
      get :validate_domain
      get :signup_validate_domain
      post :anonymous_signup
      get :anonymous_signup_complete
    end
  end

  match '/accounts/edit_domain/:perishable_token' => 'accounts#edit_domain', :as => :edit_account_domain

  resource :subscription do
    collection do
      get :plans
      get :billing
      post :billing
      post :plan
      post :calculate_amount
      put :convert_subscription_to_free
      post :calculate_plan_amount
      post :request_trial_extension
      delete :cancel_request
    end
  end

  resources :subscription_invoices, :only => [:index] do
    collection do
      get :download_invoice
    end
  end

  match '/signup/:plan/:discount' => 'accounts#new', :as => :new_account, :plan => nil, :discount => nil
  match '/account/forgot' => 'user_sessions#forgot', :as => :forgot_password
  match '/account/reset/:token' => 'user_sessions#reset', :as => :reset_password
  match '/search_user_domain' => 'domain_search#locate_domain', :as => :search_domain
  match '/email/validate_domain' => 'email#validate_domain', :as => :validate_domain
  match '/email/validate_account' => 'email#validate_account', :as => :validate_account
  match '/email/account_details' => 'email#account_details', :as => :account_details
  match '/email_service/spam_threshold_reached' => 'email_service#spam_threshold_reached', :as => :spam_threshold_reached
  match '/helpdesk/tickets/execute_scenario(/:id)' => 'helpdesk/tickets#execute_scenario' # For mobile apps backward compatibility
  match '/helpdesk/dashboard/:freshfone_group_id/agents' => 'helpdesk/dashboard#load_ffone_agents_by_group'

  namespace :helpdesk do
    match '/tickets/archived/filter/customer/:customer_id' => 'tickets#index', :as => :customer_filter, via: :get
    match '/tickets/archived/filter/requester/:requester_id' => 'archive_tickets#index', :as => :archive_requester_filter, via: :get
    match '/tickets/archived/filter/company/:company_id' => 'archive_tickets#index', :as => :archive_company_filter, via: :get
    match '/tickets/archived/:id' => 'archive_tickets#show', :as => :archive_ticket, via: :get
    match '/tickets/archived/:id/print' => 'archive_tickets#print_archive',via: :get
    match '/tickets/archived' => 'archive_tickets#index', :as => :archive_tickets, via: :get
    match '/tickets/archived/filter/tags/:tag_id' => 'archive_tickets#index', :as => :tag_filter

    match '/tickets/collab/:id' => 'collab_tickets#show'
    match '/tickets/collab/:id/notify' => 'collab_tickets#notify', via: :post
    match '/tickets/collab/:id/prevnext' => 'collab_tickets#prevnext'
    match '/tickets/collab/:id/latest_note' => 'collab_tickets#latest_note'
    match '/tickets/collab/:id/convo_token' => 'collab_tickets#convo_token'

    resources :archive_tickets, :only => [:index, :show] do
      collection do
        post :custom_search
        post :export_csv
        get :configure_export
        get :full_paginate
      end

      member do
        get :latest_note
        get :activities
        get :activitiesv2
        get :prevnext
        get :component
      end

      resources :archive_notes, :only => [:index] do
        member do
          get :full_text
        end
      end
    end

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
        delete :delete_forever_spam
        get :user_ticket
        get :search_tweets
        post :custom_search
        post :export_csv
        post :latest_ticket_count
        post :sentiment_feedback
        post :bulk_fetch_ticket_fields
        match :add_requester
        get :filter_options
        get :filter_conditions
        get :full_paginate
        get :summary
        get :compose_email
        get :update_multiple_tickets
        get :update_all_tickets
        get :configure_export
        get :custom_view_save
        match :assign_to_agent#TODO-RAILS3 new route
        put :quick_assign #TODO-RAILS3 new route
        get :bulk_scenario
        put :execute_bulk_scenario
        get :search_templates
        get :accessible_templates
        post :apply_template
        get :show_children
        post :bulk_child_tkt_create
      end

      member do
        get :reply_to_conv
        get :forward_conv
        get :reply_to_forward
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
        get :activitiesv2
        get :activities_all
        delete :clear_draft
        post :save_draft
        put :update_ticket_properties
        get :component
        get :prevnext
        put :update_requester
        get :refresh_requester_widget
        post :create # For Mobile apps backward compatibility.
        get :associated_tickets
        put :link
        put :unlink
        get :ticket_association
        put :send_and_set_status
        get :fetch_errored_email_details
        put :suppression_list_alert
      end

      resources :child, :only => [:new], :controller => "tickets"

      resources :surveys do
        collection do
          get :results
          post :rate
        end
      end

      resources :conversations do
        collection do
          post :reply
          put :undo_send
          post :forward
          post :note
          post :twitter
          post :reply_to_forward
          post :facebook
          get :traffic_cop
          get :full_text
          post :ecommerce
        post :broadcast
        end
      end

      resources :notes do
        collection do
          get :since
          get :agents_autocomplete
          get :public_conversation
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

      resources :time_sheets do
        member do
          put :toggle_timer
        end
      end
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

    resources :select_all_ticket_actions do
      collection do
        get :select_all_message_content
        put :close_multiple
        put :spam
        put :delete
        put :update_multiple
      end
    end

    resources :merge_tickets do
      collection do
        post :complete_merge
        post :merge
        post :bulk_merge
      end
    end

    namespace :canned_responses do
      resources :folders do
        collection do
          get :edit
        end
        resources :responses do
          collection do
            delete :delete_multiple
            put :update_folder
          end
          member do
            get :delete_shared_attachments
            post :delete_shared_attachments
          end
        end
      end
    end

    resources :ca_folders

    resources :canned_responses do
      collection do
        get :search
        get :recent
        get :folders
      end
    end

    match 'canned_responses/show/:id'  => 'canned_responses#show'
    match 'canned_responses/index/:id' => 'canned_responses#index', :as => :canned_responses_index
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
    match '/tickets/get_solution_detail/:id/:language' => 'tickets#get_solution_detail'
    match '/tickets/filter/tags/:tag_id' => 'tickets#index', :as => :tag_filter
    match '/tickets/filter/reports/:report_type' => 'tickets#index', :as => :reports_filter
    match '/tickets/dashboard/:filter_type/:filter_key' => 'tickets#index', :as => :dashboard_filter

    match '/dashboard' => 'dashboard#index', :as => :formatted_dashboard
    match '/dashboard/show/:resource_id' => 'dashboard#show'
    match '/dashboard/activity_list' => 'dashboard#activity_list'
    match '/dashboard/latest_activities' => 'dashboard#latest_activities'
    match '/dashboard/latest_summary' => 'dashboard#latest_summary'
    match '' => 'dashboard#index', :as => :dashboard
    match '/sales_manager' => 'dashboard#sales_manager'
    match '/dashboard/unresolved_tickets' => 'dashboard#unresolved_tickets'
    match '/dashboard/unresolved_tickets_data' => 'dashboard#unresolved_tickets_data'
    match '/tickets_summary' => 'dashboard#tickets_summary'
    match '/dashboard/due_today' => 'dashboard#due_today'
    match '/dashboard/overdue' => 'dashboard#overdue'
    match '/dashboard/trend_count' => 'dashboard#trend_count'
    match '/dashboard/unresolved_tickets_dashboard' => 'dashboard#unresolved_tickets_dashboard'
    match '/dashboard/unresolved_tickets_workload' => 'dashboard#unresolved_tickets_workload'
    match '/dashboard/my_performance'   => 'dashboard#my_performance'
    match '/dashboard/my_performance_summary'   => 'dashboard#my_performance_summary'
    match '/dashboard/agent_performance'  => 'dashboard#agent_performance'
    match '/dashboard/agent_performance_summary'  => 'dashboard#agent_performance_summary'
    match '/dashboard/group_performance'  => 'dashboard#group_performance'
    match '/dashboard/group_performance_summary'  => 'dashboard#group_performance_summary'
    match '/dashboard/channels_workload'  => 'dashboard#channels_workload'
    match '/dashboard/admin_glance'  => 'dashboard#admin_glance'
    match '/dashboard/top_customers_open_tickets'  => 'dashboard#top_customers_open_tickets'
    match '/dashboard/top_agents_old_tickets'  => 'dashboard#top_agents_old_tickets'
    match '/dashboard/available_agents' => 'dashboard#available_agents'
    match '/dashboard/survey_info' => 'dashboard#survey_info'
    match '/dashboard/achievements' => 'dashboard#achievements'
    match '/dashboard/agent_status' => 'dashboard#agent_status'

    # For mobile apps backward compatibility.
    match '/subscriptions' => 'subscriptions#index'
    match '/tickets/delete_forever/:id' => 'tickets#delete_forever'
    # Mobile apps routes end.

    match '/sales_manager' => 'dashboard#sales_manager'
    match '/agent-status' => 'dashboard#agent_status'

    resources :attachments do
      member do
        delete :unlink_shared
        get :text_content
        get :download_all
        post :create_attachment
        delete :delete_attachment
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
        put :company_sla
      end
    end

    resources :autocomplete do
      collection do
        get :requester
        post :company
      end
    end

    match 'commons/group_agents/(:id)'    => "commons#group_agents"
    match 'commons/agents_for_groups/(:id)'    => "commons#agents_for_groups"
    match 'commons/user_companies'        => "commons#user_companies", via: :post
    match "commons/fetch_company_by_name" => "commons#fetch_company_by_name"
    match 'commons/status_groups'         => "commons#status_groups"

    resources :ticket_templates do
      member do
        get :clone
        post :unlink_parent
        post :add_existing_child
      end
      collection do
        get :all_children
        get :search_children
        get :verify_template_name
        post :apply_existing_child
        delete :delete_multiple
      end
    end
    match '/ticket_templates/tab/:current_tab'    => 'ticket_templates#index',     :as => :my_ticket_templates
    match '/parent_template/:p_id/child/new'      => 'ticket_templates#new_child', :as => :new_child_template
    match '/parent_template/:p_id/child/:id/edit' => 'ticket_templates#edit_child',:as => :edit_child_template

    resources :scenario_automations do
      member do
        get :clone
      end
      collection do
        get :search
        get :recent
      end
    end
  end
  match '/helpdesk/scenario_automations/tab/:current_tab', :controller => 'helpdesk/scenario_automations', :action => 'index'

  match '/helpdesk/tickets/quick_assign/:id' => "Helpdesk::tickets#quick_assign", :as => :quick_assign_helpdesk_tickets,
    :method => :put

  resources :api_webhooks, :path => 'webhooks/subscription'

  namespace :solution do
    resources :categories do
      collection do
        put :reorder
        get :sidebar
        get :navmenu
        get :drafts
        get :feedbacks
      end

      resources :folders do
        collection do
          put :reorder
          put :move_to
          put :move_back
        end

        resources :articles do
          collection do
            put :reorder
            put :move_to
            put :move_back
            put :mark_as_outdated
            put :mark_as_uptodate
          end

          member do
            put :thumbs_up
            put :thumbs_down
            post :delete_tag
            delete :destroy
            put :reset_ratings
            get :properties
            get :voted_users
            put :translate_parents
          end
          resources :tag_uses
        end
      end
    end

    resources :folders do
      collection do
        put :reorder
        put :move_to
        put :move_back
        put :visible_to
      end
    end

    resources :articles do
      collection do
        put :reorder
        put :move_to
        put :move_back
        put :mark_as_outdated
        put :mark_as_uptodate
      end

      member do
        put :thumbs_up
        put :thumbs_down
        post :delete_tag
        delete :destroy
        put :reset_ratings
        get :properties
        get :voted_users
        get :show_master
        put :translate_parents
      end

      resources :tag_uses
      match '/:attachment_type/:attachment_id/delete' => "drafts#attachments_delete", :as => :attachments_delete, :via => :delete
    end

    resources :drafts, :only => [:index]
    get '/drafts/:type' => "drafts#index", :as => :my_drafts
    post 'drafts/:article_id/:language_id/autosave' => "drafts#autosave", :as => :draft_autosave
    post 'drafts/:article_id/:language_id/publish' => "drafts#publish", :as => :draft_publish
    delete 'drafts/:article_id/:language_id/delete' => "drafts#destroy", :as => :draft_delete
    delete 'drafts/:article_id/:language_id/:attachment_type/:attachment_id/delete' => "drafts#attachments_delete", :as => :draft_attachments_delete

    match '/articles/:id/:language' => "articles#show", :as => :article_version, :via => :get
    match '/articles/:id/:language' => "articles#update", :as => :article_version, :via => :put
    match '/all_categories/(:portal_id)' => "categories#all_categories", :as => :all_categories, :via => :get
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

      member do
        get :followers
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
        get :users_voted
      end

      resources :posts, :except => :new do
        member do
          put :toggle_answer
          get :users_voted
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
        get :moderation_count
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
    match '/unpublished/filter/:filter' => 'unpublished#index', :as => :unpublished_filter
    resources :merge_topic do
      collection do
        post :select
        put :review
        post :confirm
        put :merge
      end
    end
  end

  namespace :aloha, only: [:callback] do
    resources :signup do
      collection do
        post :callback
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

  resources :posts

  match '/discussions/categories.:format' => 'discussions#create', :via => :post
  match '/discussions/categories/:id.:format' => 'discussions#show', :via => :get
  match '/discussions/categories/:id.:format' => 'discussions#destroy', :via => :delete
  match '/discussions/categories/:id.:format' => 'discussions#update', :via => :put

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

  match '/helpdesk/tickets/:id/suggest/tickets' => 'helpdesk/tickets#suggest_tickets'
  match '/helpdesk/tickets/:id/ticket_properties' => 'helpdesk/tickets#bulk_fetch_ticket_fields'
  match '/support/theme.:format' => 'theme/support#index'
  match '/support/theme_rtl.:format' => 'theme/support_rtl#index'
  match '/helpdesk/theme.:format' => 'theme/helpdesk#index'
  match "/facebook/theme.:format", :controller => 'theme/facebook', :action => :index

  get 'discussions/:object/:id/subscriptions/is_following(.:format)',
    :controller => 'monitorships', :action => 'is_following',
    :as => :get_monitorship

  get 'discussions/:object/:id/subscriptions',
    :controller => 'monitorships', :action => 'followers',
    :as => :view_monitorship

  match 'discussions/:object/:id/subscriptions/:type(.:format)',
    :controller => 'monitorships', :action => 'toggle',
    :as => :toggle_monitorship

  filter :locale

  match '/announcements' => 'announcements#index',via: :get
  match '/announcements/account_login_url' => 'announcements#account_login_url',via: :get

  namespace :support do
    match 'home' => 'home#index', :as => :home
    match 'preview' => 'preview#index', :as => :preview
    resource :login, :controller => "login", :only => [:new, :create]
    match '/login' => 'login#new'
    resource :signup, :only => [:new, :create]
    match '/signup' => 'signups#new'

    resource :profile, :only => [:edit, :update]

    # Search v2 portal controller routes
    #
    namespace :search_v2 do
      resources :spotlight, :only => [:all, :tickets, :solutions, :topics, :suggest_topic] do
        collection do
          get :all
          get :tickets
          get :solutions
          get :topics
          get :suggest_topic
        end
      end
      resources :solutions, :only => [:related_articles] do
        collection do
          get :related_articles
        end
      end
    end

    resource :search, :controller => "search", :only => :show do
      member do
        get :solutions
        get :topics
        get :tickets
        get :suggest_topic
      end
      match '/topics/suggest', :action => 'suggest_topic'
      match '/articles/:article_id/related_articles', :action => 'related_articles', via: :get
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
          put :toggle_vote
        end

        resources :posts, :except => [:index, :new, :show] do
          member do
            put :toggle_answer
            put :like
            get :users_voted
            put :toggle_vote
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
      match '/categories/:id', :action => 'show'
      match '/folders/:id/page/:page' => 'folders#show'
      match '/categories/:category_id/folders/:id' => 'folders#show'
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

    match '/solutions/articles/:id/:status' => 'solutions/articles#show', :as => :draft_preview

    match '/articles/:id/' => 'solutions/articles#show'

    namespace :multilingual do
      resources :solutions, :only => [:index, :show]

      namespace :solutions do
        match '/categories/:id', :action => 'show'
        match '/folders/:id/page/:page' => 'folders#show'
        match '/categories/:category_id/folders/:id' => 'folders#show'
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

      match '/solutions/articles/:id/:status' => 'solutions/articles#show', :as => :draft_preview

      match '/articles/:id/' => 'solutions/articles#show'
    end

    match '/tickets/archived/:id' => 'archive_tickets#show', :as => :archive_ticket, via: :get
    match '/tickets/archived' => 'archive_tickets#index', :as => :archive_tickets, via: :get
    resources :archive_tickets, :only => [:index, :show] do
      collection do
        get :filter
        get :configure_export
        post :export_csv
      end
      resources :notes
    end

    resources :tickets do
      collection do
        post :check_email
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

    resources :bot_responses do
      collection do
        get :filter
        put :update_response
      end
    end

    match '/surveys/:ticket_id' => 'surveys#create_for_portal', :as => :portal_survey
    match '/surveys/:survey_code/:rating/new' => 'surveys#new', :as => :customer_survey
    match '/surveys/:survey_code/:rating' => 'surveys#create', :as => :survey_feedback, :via => :post

    match '/custom_surveys/:id/preview' => 'custom_surveys#preview', :as => :custom_survey_preview
    match '/custom_surveys/:id/preview/questions' => 'custom_surveys#preview_questions', :as => :custom_survey_preview_questions

    match '/custom_surveys/:survey_result/:rating' => 'custom_surveys#create', :as => :custom_survey_feedback, :via => :post
    match '/custom_surveys/:survey_code/:rating/new' => 'custom_surveys#new_via_handle' ,:as => :customer_custom_survey
    match '/custom_surveys/:survey_code/:rating/hit' => 'custom_surveys#hit' ,:as => :customer_custom_survey_hit
    match '/custom_surveys/:ticket_id/:rating'  => 'custom_surveys#new_via_portal', :as => :portal_custom_survey

    match '/user_credentials/refresh_access_token/:app_name',
      :controller => 'integrations/user_credentials', :action => 'refresh_access_token', :as => :refresh_token
    match '/integrations/user_credentials/oauth_install/:app_name',
      :controller => 'integrations/user_credentials', :action => 'oauth_install', :as => :user_oauth_install
    match '/http_request_proxy/fetch',
      :controller => 'integrations/http_request_proxy', :action => 'fetch', :as => :http_proxy

    namespace :canned_forms do
      get :agent_preview, action: 'preview'
      post :preview, action: 'preview'
      get '/:token', action: 'show', as: :response
      post '/:token/new', action: 'new'
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
        get :get_filtered_tickets
        get :get_solution_url
        get :mobile_filter_count
        get :bulk_assign_agent_list
        post :recent_tickets
        match '/ticket_properties/:id' => 'tickets#ticket_properties', :via => :get
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
        get :mobile_login
        get :mobile_pre_loader
        get :deliver_activation_instructions
        get :configurations
        get :mobile_configurations
      end
    end
    resources :freshfone do
      collection do
        get :numbers
        get :can_accept_incoming_calls
        get :is_ringing
      end
    end
  end

  namespace :notification do
    resources :product_notification, :only => :index
    resources :user_notification, :only => :index do
      collection do
        get :token
      end
    end


  end

  resources :rabbit_mq, :only => [:index]
  match '/openid/google', :controller => "integrations/marketplace/google", :action => "old_app_redirect"
  match '/google/login', :controller => "sso", :action => "mobile_app_google_login"
  match '/' => 'home#index'
  # match '/:controller(/:action(/:id))'
  match '/all_agents' => 'agents#list'
  match '/download_file/:source/:token', :controller => 'admin/data_export', :action => 'download', :method => :get
  match '/chat/agents', :controller => 'chats', :action => 'agents', :method => :get


  constraints(lambda {|req| PartnerSubdomains.include?(req.subdomain) })  do
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
        post :fetch_affiliates
        post :edit_affiliate
      end
    end
  end
  end

  constraints(lambda {|req| req.subdomain == AppConfig['billing_subdomain'] }) do
    # namespace :billing do
    resources :billing, :controller => 'billing/billing' do
      collection do
        post :trigger
      end
    end
    # end
  end

  namespace :supreme do
    resources :sql_console, :only => :none do
      collection do
        get :execute_query
      end
    end
  end

  constraints(lambda {|req| FreshopsSubdomains.include?(req.subdomain) })  do
    namespace :fdadmin, :name_prefix => "fdadmin_", :path_prefix => nil do

      resources :billing, :only => :none do
        collection do
          post :trigger
        end
      end

      resources :freshops_pod, :only => :none do
        collection do
          get :fetch_pod_info
          post :pod_endpoint
        end
      end

      resources :subscriptions, :only => [:none] do
        collection do
          get :display_subscribers
          get :customers
          get :customer_summary
          get :deleted_customers
          get :account_subscription_info
        end
      end

      resources :jobs, only: [:index,:show] do
        collection do
          put 'requeue'
          put 'requeue_selected'
          put 'remove_selected'
          put 'destroy_job'
        end
      end

      get  "/accounts/show", to: 'accounts#show'

      resources :accounts, :only => :none do
        collection do
          get :tickets
          get :agents
          get :portal
          get :features
          get :email_config
          get :latest_solution_articles
          put :add_day_passes
          post :migrate_to_freshconnect
          put :change_api_limit
          put :change_v2_api_limit
          put :change_fluffy_limit
          put :change_fluffy_min_level_limit
          put :change_webhook_limit
          put :add_feature
          put :change_url
          get :single_sign_on
          put :change_account_name
          put :ublock_account
          put :suspend_account
          put :reactivate_account
          put :remove_feature
          put :whitelist
          put :block_account
          get :user_info
          get :check_contact_import
          put :reset_login_count
          post :contact_import_destroy
          post :select_all_feature
          post :sha256_enabled_feature
          post :sha1_enabled_feature
          post :api_jwt_auth_feature
          post :collab_feature
          put :change_currency
          get :check_domain
          put :unblock_outgoing_email
          post :extend_trial
          put :change_primary_language
          get :clone_account  
          post :clone_account
          post :trigger_action
          get :clone_account
          post :clone_account
          post :enable_freshid
          post :make_account_admin
          put :enable_fluffy
          put :change_fluffy_plan
          post :extend_higher_plan_trial
          post :change_trial_plan
          put :enable_min_level_fluffy
          put :disable_min_level_fluffy
          get :min_level_fluffy_info
          post :reset_ticket_display_id
          post :disable_freshid_org_v2
          post :enable_freshid_org_v2
          post :validate_and_fix_freshid
          post :skip_mandatory_checks
        end
      end

      resources :custom_ssl, :only => :index do
        collection do
          put :enable_custom_ssl
        end
      end

      resources :account_tools, :only => :index do
        collection do
          put :update_global_blacklist_ips
          put :remove_blacklisted_ip
          get :shards
          post :operations_on_shard
          get :blacklisted_domains
          put :add_blacklisted_domain
          put :remove_blacklisted_domain
          get :fetch_latest_shard
          get :redis_signup_shards
          post :add_shard_to_redis
          post :remove_shard_from_redis
        end
      end

      resources :freshfone_actions do
        collection do
          put :add_credits
          put :refund_credits
          put :twilio_port_in
          put :suspend_freshfone
          put :account_closure
          put :get_country_list
          put :country_restriction
          put :trigger_whitelist
          get :get_country_list
          get :fetch_usage_triggers
          put :update_usage_triggers
          put :restore_freshfone_account
          post :country_restriction
          post :new_freshfone_account
          put :undo_security_whitelist
          get :fetch_conference_state
          put :enable_conference
          put :disable_conference
          put :update_timeouts_and_queue
          get :fetch_numbers
          put :twilio_port_away
          put :activate_trial
          put :launch_feature
          get :launched_feature_details
          put :activate_onboarding
        end
      end

      namespace :freshfone_stats do
        resources :usage do
          collection do
            get :global_conference_usage_csv
            get :global_conference_usage_csv_by_account
          end
        end

        resources :renewal do
          collection do
            get :renewal_backlog_csv
            get :failed_renewal_csv
            get :failed_renewal_csv_by_account
            get :renewal_backlog_csv_by_account
          end
        end

        resources :phone_number do
          collection do
            get :phone_statistics
            get :deleted_freshfone_csv_by_account
            get :deleted_freshfone_csv
            get :all_freshfone_number_csv
            get :purchased_numbers_csv
            get :purchased_numbers_csv_by_account
          end
        end

        resources :credits do
          collection do
            get :request_csv
            get :request_csv_by_account
          end
        end

        resources :payments do
          collection do
            get :statistics
            get :request_csv
            get :request_csv_by_account
            get :active_accounts_csv
          end
        end

        resources :call_quality_metrics do
          collection do
            get :export_csv
          end
        end

        resources :subscriptions do
          collection do
            get :stats_by_account
            get :stats_csv
            get :recent_stats
          end
        end

      end

      resources :freshfone_subscriptions do
        collection do
          get :index
        end
      end

      resources :spam_watch, :only => :none do
        collection do
          get :spam_details
          put :block_user
          put :unblock_user
          put :hard_block
          put :spam_user
          put :internal_whitelist
          put :unspam_user
        end
      end

      resources :subscription_events, :only => :none do
        collection do
          get :current_month_summary
          get :custom_month
          get :export_to_csv
        end
      end

      resources :users, :only => :none do
        collection do
          get 'get_user'
        end
      end

      resources :subscription_plans, only: :none do
        collection do
          get :all_plans
        end
      end

      resources :subscription_announcements, :only => [:create,:index] do
        collection do
          put 'update'
          delete 'destroy'
        end
      end

      resources :manage_users, :only => :none do
        collection do
          get :get_whitelisted_users
          post :add_whitelisted_user_id
          delete :remove_whitelisted_user_id
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

  resources :livechat, :controller => 'chats', :only =>:index do
    collection do
      post :create_ticket
      post :add_note
      post :enable
      get  :get_groups
      get  :agents
      put  :toggle
      put  :update_site
      put  :trigger
      get  :export
    end
  end
  match '/livechat/visitor/:type', :controller => 'chats', :action => 'visitor', :method => :get
  match '/livechat/downloadexport/:token', :controller => 'chats', :action => 'download_export', :method => :get


  post '/livechat/shortcodes', :controller => 'chats', :action => 'create_shortcode', :method => :post
  delete '/livechat/shortcodes/:id', :controller => 'chats', :action => 'delete_shortcode', :method => :delete
  put '/livechat/shortcodes/:id', :controller => 'chats', :action => 'update_shortcode', :method => :put
  put '/livechat/agent/:id/update_availability', :controller => 'chats', :action => 'update_availability', :method => :put
  match '/livechat/*letter', :controller => 'chats', :action => 'index', :method => :get

  use_doorkeeper do
    skip_controllers :oauth_applications, :authorized_applications
    controllers :authorizations => 'Doorkeeper::Authorize'
  end

  namespace :doorkeeper, :path => '' do
    namespace :api, :path => '' do
      namespace :marketplace do
        get :data
      end
    end
  end

  match "/admin/bot", to: redirect('/helpdesk')
  match "/admin/bot/*letter", to: redirect('/helpdesk')
  match "/bot/*letter", to: redirect('/helpdesk')

  match "/admin/advanced-ticketing", to: redirect('/helpdesk')

  match '/freshid/authorize_callback', :controller => 'freshid', :action => 'authorize_callback', :method => :get
  match '/freshid/customer_authorize_callback', :controller => 'freshid', :action => 'customer_authorize_callback', :method => :get
  match '/freshid/event_callback', :controller => 'freshid', :action => 'event_callback', :method => :post
  match '/freshid/logout', :controller => 'user_sessions', :action => 'freshid_destroy', :method => :get

  post '/yearin_review/share', to: 'year_in_review#share'
  post '/yearin_review/clear', to: 'year_in_review#clear'
  
  match '/mobile/welcome'  => 'mobile_app_download#index'
  match '/email_service_spam' => 'email_service#create', via: :post
end
