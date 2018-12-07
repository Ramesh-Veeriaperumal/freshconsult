Helpkit::Application.routes.draw do
  api_routes = proc do
    resources :tickets, except: [:new, :edit] do
      collection do
        post :outbound_email, to: 'tickets#create', defaults: { _action: 'compose_email' }
      end
      member do
        put :restore
        get :time_entries, to: 'time_entries#ticket_time_entries'
        get :conversations, to: 'conversations#ticket_conversations'
        get :satisfaction_ratings, to: 'satisfaction_ratings#survey_results'
        post :satisfaction_ratings, to: 'satisfaction_ratings#create'
        post :reply, to: 'conversations#reply'
        post :notes, to: 'conversations#create'
        post :forward, to: 'api_conversations#forward'
        post :reply_to_forward, to: 'api_conversations#reply_to_forward'
        post :time_entries, to: 'time_entries#create'
        get :sessions, to: 'admin/freshmarketer#sessions'
        resource :bot_response, controller: 'tickets/bot_response', only: [:show, :update]
      end
    end

    match '_search/tickets' => 'tickets#search', as: :tickets_search, via: :get

    resources :conversations, except: [:new, :edit, :show, :index, :create]

    resources :ticket_fields, controller: :api_ticket_fields, only: [:index]

    resources :time_entries, except: [:new, :edit, :show, :create] do
      member do
        put :toggle_timer
      end
    end

    namespace :api_freshfone, path: 'phone' do
      resources :call_history, only: [:index] do
        collection do
          post :export
          get '(export/:id)', to: :export_status, as: :export_status
        end
      end
    end

    namespace :api_discussions, path: 'discussions' do
      resources :categories, except: [:new, :edit] do
        member do
          get :forums, to: 'forums#category_forums'
          post :forums, to: 'forums#create'
        end
      end
      resources :forums, except: [:new, :edit, :index, :create] do
        member do
          get :topics, to: 'topics#forum_topics'
          post :follow, to: :follow
          delete :follow, to: :unfollow
          get :follow, to: :is_following
          post :topics, to: 'topics#create'
        end
      end
      resources :topics, except: [:new, :edit, :index, :create] do
        member do
          get :comments, to: 'api_comments#topic_comments'
          post :follow, to: :follow
          delete :follow, to: :unfollow
          get :follow, to: :is_following
          post :comments, to: 'api_comments#create'
        end
        collection do
          get :followed_by
          get :participated_by
        end
      end
      resources :comments, as: 'api_comments', controller: 'api_comments', only: [:destroy, :update]
    end
    resources :groups, as: 'api_groups', controller: 'api_groups', except: [:new, :edit]

    namespace :api_search, path: 'search' do
      resources :tickets, only: [:index]
      resources :contacts, only: [:index]
      resources :companies, only: [:index]
      post :solutions, to: 'solutions#results'
      get :solutions, to: 'solutions#results'
    end

    resources :contacts, as: 'api_contacts', controller: 'api_contacts', except: [:new, :edit] do
      member do
        put :make_agent
        put :restore
        delete :hard_delete
        put :send_invite, to: 'contacts/misc#send_invite'
      end
      collection do
        post :merge, to: 'contacts/merge#merge'
        resources :imports, controller: 'api_customer_imports', only: [:index, :create, :show] do
          member do
            put :cancel
          end
        end
        post :export, to: 'contacts/misc#export'
        get 'export/:id', to: 'contacts/misc#export_details'
      end
    end

    match 'agents/me' => 'api_profiles#show', :defaults => { format: 'json', id: 'me' }, via: :get
    match 'agents/me' => 'api_profiles#update', :defaults => { format: 'json', id: 'me' }, via: :put
    match 'agents/me/reset_api_key' => 'api_profiles#reset_api_key', :defaults => { format: 'json', id: 'me' }, via: :post

    resources :agents, controller: 'api_agents', only: [:index, :show, :update, :destroy]
    
    resources :canned_response_folders, controller: 'canned_response_folders', only: [:index, :show, :create, :update]
    resources :canned_responses, controller: 'canned_responses', only: [:index, :show, :create, :update]
    resources :scenario_automations, controller: 'scenario_automations', only: :index
    get 'canned_response_folders/:id/responses', to: 'canned_responses#folder_responses'

    resources :surveys, only: [:index] do
      collection do
        get :satisfaction_ratings, to: 'satisfaction_ratings#index'
      end
    end

    resources :contact_filters, controller: 'ember/segments/contact_filters', only: [:index, :create, :update, :destroy]
    resources :company_filters, controller: 'ember/segments/company_filters', only: [:index, :create, :update, :destroy]

    resources :roles, controller: 'api_roles', only: [:index, :show]

    namespace :settings do
      resources :helpdesk, only: [:index]
    end

    match 'export/ticket_activities' => 'export#ticket_activities', :defaults => { format: 'json' }, :as => :ticket_activities, via: :get
    match 'rake_task/run_rake_task' => 'rake_task#run_rake_task', :defaults => { format: 'json' }, :as => :run_rake_task, via: :get

    resources :automation_essentials, only: [] do
      collection do
        get :lp_launched_features
        put :lp_launch
        put :lp_rollback
      end
    end

    # Feedbacks about the product
    resources :product_feedback, controller: 'ember/product_feedback', only: [:create]

    # Solution endpoints
    namespace :api_solutions, path: 'solutions' do
      resources :categories, only: [:create, :destroy], constraints: { id: /\d+/ } do
        member do
          resources :folders, only: [:create] do
            collection do
              get '(/:language)', to: :category_folders
            end
          end
          post '/:language', to: :create
          get '(/:language)', to: :show
          put '(/:language)', to: :update
        end

        collection do
          get '(/:language)', to: :index
        end
      end

      resources :folders, only: [:destroy], constraints: { id: /\d+/ } do
        member do
          resources :articles, only: [:create] do
            collection do
              get '(/:language)', to: :folder_articles
            end
          end
          post '/:language', to: :create
          get '(/:language)', to: :show
          put '(/:language)', to: :update
        end
      end

      resources :articles, only: [:destroy], constraints: { id: /\d+/ } do
        member do
          post '/:language', to: :create
          get '(/:language)', to: :show
          put '(/:language)', to: :update
        end
      end
    end

    resources :contact_fields, controller: 'api_contact_fields', only: [:index]

    resources :products, controller: 'api_products', only: [:index, :show]

    resources :email_configs, controller: 'api_email_configs', only: [:index, :show, :search]

    resources :business_hours, controller: 'api_business_hours', only: [:index, :show]

    resources :companies, as: 'api_companies', controller: 'api_companies', except: [:new, :edit] do
      collection do
        resources :imports, controller: 'api_customer_imports', only: [:index, :create, :show] do
          member do
            put :cancel
          end
        end
        post :export, to: 'companies/misc#export'
        get 'export/:id', to: 'companies/misc#export_details'
      end
    end

    resources :company_fields, as: 'api_company_fields', controller: 'api_company_fields', only: [:index]

    namespace :api_integrations, path: 'integrations' do
      namespace :cti, path: 'cti' do
        post :pop, action: :create
        get :details, action: :index
      end
    end
    resources :sla_policies, controller: 'api_sla_policies', only: [:index, :update]

    resources :archived_tickets ,  path: 'tickets/archived', controller: 'archive/tickets', only: [:show, :destroy] do
      member do
        get :conversations, to: 'archive/conversations#ticket_conversations'
      end
    end

    resources :canned_forms, controller: 'admin/canned_forms', path: '/canned_forms' do
      member do
        post :handle, to: 'admin/canned_forms#create_handle'
      end
    end

    resources :freshmarketer, controller: 'admin/freshmarketer', only: :index do
      collection do
        put :link
        delete :unlink
        put :enable_integration
        put :disable_integration
        get :session_info
      end
    end

    resources :attachments, controller: 'api_attachments', only: [:destroy]
    # Proactive Support routes
    scope '/proactive' do
      resources :rules, controller: 'proactive/rules', except: [:edit] do
        collection do
          post :filters
          post :placeholders
          post :preview_email
        end
      end
    end

    resources :email_notifications, controller: 'admin/api_email_notifications', only: [:show, :update]
    
    resources :help_widgets, controller: 'help_widgets'
    
  end

  ember_routes = proc do
    resources :ticket_fields, controller: 'ember/ticket_fields', only: [:index, :update]
    resources :groups, controller: 'ember/groups', only: [:index, :show, :create, :update, :destroy]

    resources :roles, controller: 'api_roles', only: [:index] do
      collection do
        post 'bulk_update'
      end
    end

    resources :email_configs, controller: 'ember/email_configs' do
      collection do
        get :search, to: 'ember/email_configs#search'
      end
    end

    # trial subscriptions
    resources :trial_subscription, controller: 'admin/trial_subscriptions', only: [:create] do
      collection do
        put :cancel
        get :usage_metrics
      end
    end

    resources :bootstrap, controller: 'ember/bootstrap', only: :index do
      collection do
        get :agents_groups, to: 'ember/bootstrap/agents_groups#index'
        get :me, to: 'ember/bootstrap#me'
        get :account, to: 'ember/bootstrap#account'
      end
    end
    
    resource :accounts, controller: 'admin/api_accounts' do
      collection do
        post :cancel
      end
    end

    post '/account/export', to: 'admin/api_data_exports#account_export'

    resources :topics, controller: 'ember/discussions/topics', only: [:show] do
      member do
        get :first_post
      end
    end

    resources :chatsetting, controller: 'ember/livechat_setting', only: :index
    resources 'freshcaller_desktop_notification_settings', path: 'freshcaller/settings', controller: 'ember/freshcaller/settings', only: [:index] do
      collection do
        put :desktop_notification
        get :redirect_url
      end
    end

    resources :bots, controller: 'ember/admin/bots', only: [:index, :new, :create, :show, :update] do
      member do
        put :map_categories
        post :mark_completed_status_seen
        put :enable_on_portal
        get :bot_folders
        post :create_bot_folder
        get :analytics
        put :remove_analytics_mock_data
      end
      member do
        resources :bot_feedbacks, controller: 'ember/admin/bot_feedbacks', only: [:index] do
          member do
            get :chat_history
          end
          collection do
            put :bulk_delete
            put :bulk_map_article
            post :create_article
          end
        end
      end
    end

    resources :advanced_ticketing, controller: 'ember/admin/advanced_ticketing', only: [ :create, :destroy ] do
      collection do
        get :insights
      end
    end

    match 'tickets/archived/export' => 'archive/tickets#export', via: :post
    match 'tickets/archived/:id/activities' => 'archive/tickets/activities#index', via: :get
    match 'freshconnect_account' => 'ember/freshconnect#update', via: :put

    resources :tickets, controller: 'ember/tickets', only: [:index, :create, :update, :show] do
      collection do
        post :outbound_email, to: 'ember/tickets#create', defaults: { _action: 'compose_email' }
        put :bulk_delete, to: 'ember/tickets/delete_spam#bulk_delete'
        put :bulk_spam, to: 'ember/tickets/delete_spam#bulk_spam'
        put :bulk_restore, to: 'ember/tickets/delete_spam#bulk_restore'
        put :bulk_unspam, to: 'ember/tickets/delete_spam#bulk_unspam'
        post :bulk_update, to: 'ember/tickets/bulk_actions#bulk_update'
        post :bulk_execute_scenario, to: 'ember/tickets/bulk_actions#bulk_execute_scenario'
        put :bulk_link, to: 'ember/tickets/bulk_actions#bulk_link'
        put :bulk_unlink, to: 'ember/tickets/bulk_actions#bulk_unlink'
        put :merge, to: 'ember/tickets/merge#merge'
        delete :empty_trash, to: 'ember/tickets/delete_spam#empty_trash'
        delete :empty_spam, to: 'ember/tickets/delete_spam#empty_spam'
        put :delete_forever, to: 'ember/tickets/delete_spam#delete_forever'
        put :bulk_watch, to: 'ember/subscriptions#bulk_watch'
        put :bulk_unwatch, to: 'ember/subscriptions#bulk_unwatch'
        post :export_csv
      end
      member do
        delete :destroy, to: 'ember/tickets/delete_spam#destroy'
        put :spam, to: 'ember/tickets/delete_spam#spam'
        put :restore, to: 'ember/tickets/delete_spam#restore'
        put :unspam, to: 'ember/tickets/delete_spam#unspam'
        put :execute_scenario
        post :notes, to: 'ember/conversations#create'
        post :reply, to: 'ember/conversations#reply'
        put :undo_send, to: 'ember/conversations#undo_send'
        get :reply_template, to: 'ember/conversations#reply_template'
        post :reply_template, to: 'ember/conversations#reply_template'
        get :forward_template, to: 'ember/conversations#forward_template'
        post :broadcast, to: 'ember/conversations#broadcast'

        # TODO: Should rename this
        get :latest_note_forward_template, to: 'ember/conversations#latest_note_forward_template'
        post :tweet, to: 'ember/conversations#tweet'
        get :latest_note
        get :conversations, to: 'ember/conversations#ticket_conversations'
        get :time_entries, to: 'ember/time_entries#ticket_time_entries'
        post :time_entries, to: 'ember/time_entries#create'
        post :draft, to: 'ember/tickets/drafts#save_draft'
        get :draft, to: 'ember/tickets/drafts#show_draft'
        delete :draft, to: 'ember/tickets/drafts#clear_draft'
        post :notify_collab, to: 'ember/tickets/collab#notify'
        match '/split_note/:note_id' => 'ember/tickets#split_note', via: :put
        # This alternate route is to handle limitation in ember route generation : api/_/tickets/:ticket_id/split_note?note_id=Number
        match '/split_note' => 'ember/tickets#split_note', via: :put
        post :facebook_reply, to: 'ember/conversations#facebook_reply'
        get :prime_association, to: 'ember/tickets/associates#prime_association'
        put :link, to: 'ember/tickets/associates#link'
        put :unlink, to: 'ember/tickets/associates#unlink'
        get :associated_tickets, to: 'ember/tickets/associates#associated_tickets'
        put :create_child_with_template
        put :requester, to: 'ember/tickets/requester#update'
        post :parse_template, to: 'ember/tickets#parse_template'
      end
      resources :activities, controller: 'ember/tickets/activities', only: [:index]
      resource :summary, controller: 'ticket_summary', only: [:show, :update, :destroy]

      member do
        post :watch, to: 'ember/subscriptions#watch'
        put :unwatch, to: 'ember/subscriptions#unwatch'
        get :watchers, to: 'ember/subscriptions#watchers'
        put :update_properties, to: 'ember/tickets#update_properties'
        get :failed_email_details, to: 'ember/tickets#fetch_errored_email_details'
        post :suppression_list_alert, to: 'ember/tickets#suppression_list_alert'
      end
    end

    resources :time_entries, controller: 'ember/time_entries', except: [:new, :edit, :create] do
      member do
        put :toggle_timer
      end
    end

    resources :conversations, controller: 'ember/conversations', only: [:update] do
      member do
        get :full_text
        get :forward_template, to: 'ember/conversations#note_forward_template'
        get :reply_to_forward_template, to: 'ember/conversations#reply_to_forward_template'
      end
    end

    resources :todos, controller: 'ember/todos', except: [:new, :edit, :show]
    resources :installed_applications, controller: 'ember/installed_applications', only: [:index, :show] do
      member do
        post :fetch
      end
    end
    resources :integrated_resources, controller: 'ember/integrated_resources', except: [:new, :edit]
    resources :integrated_users, controller: 'ember/integrated_users', only: [:index, :show] do
      collection do
        post :credentials, to: 'ember/integrated_users#user_credentials_add'
        delete :credentials, to: 'ember/integrated_users#user_credentials_remove'
      end
    end
    resources :cloud_files, controller: 'ember/cloud_files', only: [:destroy]

    resources :trial_widget, controller: 'ember/trial_widget', only: [:index] do
      collection do
        get :sales_manager
        post :complete_step
      end
    end

    resources :contacts, controller: 'ember/contacts', except: [:new, :edit] do
      collection do
        put :bulk_delete
        put :bulk_restore
        put :bulk_send_invite
        put :bulk_whitelist
        post :quick_create
        resources :imports, controller: 'api_customer_imports', only: [:index, :create, :show] do
          member do
            put :cancel
          end
        end
      end
      member do
        put :restore
        put :whitelist
        put :update_password
        get :activities
        put :assume_identity
        delete :hard_delete
        get :timeline
      end
      resources :notes, controller: 'customer_notes', only: [:create, :update, :destroy, :show, :index]
    end

    resources :companies, controller: 'ember/companies', only: [:index, :show, :create, :update] do
      collection do
        put :bulk_delete
        resources :imports, controller: 'api_customer_imports', only: [:index, :create, :show] do
          member do
            put :cancel
          end
        end
      end
      member do
        get :activities
      end
      resources :notes, controller: 'customer_notes', only: [:create, :update, :destroy, :show, :index]
    end

    resources :attachments, controller: 'ember/attachments', only: [:create, :show] do
      member do
        put :unlink
      end
    end

    resources :ticket_filters, controller: 'ember/ticket_filters', only: [:index, :show, :create, :update, :destroy]
    resources :contact_fields, controller: 'ember/contact_fields', only: :index
    resources :company_fields, controller: 'ember/company_fields', only: :index
    resources :ticket_templates, controller: 'ember/ticket_templates', only: [:show, :index]

    resources :twitter_handles, controller: 'ember/twitter_handles', only: [:index] do
      member do
        get :check_following
      end
    end
    resources :surveys, controller: 'ember/surveys', only: [:index, :show]
    resources :portals, controller: 'ember/portals', only: [:index, :update, :show] do
      member do
        get :bot_prerequisites
      end
    end

    resources :agents, controller: 'ember/agents', only: [:index, :show, :update], id: /\d+/ do
      collection do
        post :create_multiple
        get :revert_identity
        post :complete_gdpr_acceptance
        post :enable_undo_send
        post :disable_undo_send
      end
      member do
        get :achievements
        put :assume_identity
      end
    end

    get 'canned_responses/search', to: 'ember/canned_responses#search'
    
    # audit log path
    post '/audit_log', to: 'audit_logs#filter'
    post '/audit_log/export', to: 'audit_logs#export'
    get '/audit_log/event_name', to: 'audit_logs#event_name'

    # account update
    put '/account_admin', to: 'account_admins#update'

    # dirty hack - check privilege fails when using 'solutions' namespace although controller action mapping is unaffected
    get 'solutions/articles', to: 'ember/solutions/articles#index'
    get 'solutions/articles/:id/article_content', to: 'ember/solutions/articles#article_content'

    resources :marketplace_apps, controller: 'ember/marketplace_apps', only: [:index]

    # match '/dashboards/widget_data_preview'=> 'ember/custom_dashboard#widget_data_preview', via: :get

    resources :dashboards, controller: 'ember/custom_dashboard' do
      member do
        get :widgets_data, to: 'ember/custom_dashboard#widgets_data'
        get :bar_chart_data, to: 'ember/custom_dashboard#bar_chart_data'
        post :announcements, to: 'ember/custom_dashboard#create_announcement'
        put :announcements, to: 'ember/custom_dashboard#end_announcement'
        get :announcements, to: 'ember/custom_dashboard#get_announcements'
        resources :announcements do
          get '', to: 'ember/custom_dashboard#fetch_announcement'
        end
      end

      collection do
        get :widget_data_preview, to: 'ember/custom_dashboard#widget_data_preview'
        get :leaderboard_agents, to: 'ember/leaderboard#agents'
        get :leaderboard_groups, to: 'ember/leaderboard#groups'
      end
    end

    resources :default_dashboards, controller: 'ember/dashboard', only: [:show] do
      collection do
        get :satisfaction_survey, to: 'ember/dashboard#survey_info'
        get :moderation_count, to: 'ember/dashboard#moderation_count'
        get :ticket_trends, to: 'ember/dashboard#ticket_trends'
        get :ticket_metrics, to: 'ember/dashboard#ticket_metrics'
        get :unresolved_tickets, to: 'ember/dashboard#unresolved_tickets_data'
        get :ticket_summaries, to: 'ember/dashboard#scorecard'
        get :activities, to: 'ember/dashboard/activities#index'
        get :quests, to: 'ember/dashboard/quests#index'
      end
    end

    resource :onboarding, controller: 'ember/admin/onboarding', only: [:index] do
      collection do
        put :update_activation_email
        get :resend_activation_email
        post :update_channel_config
        get :forward_email_confirmation
        post :test_email_forwarding
        get :suggest_domains
        post :validate_domain_name 
        put :customize_domain
      end
    end

    resources :sandboxes, controller: 'admin/sandboxes', only: [:index, :create, :destroy] do
      member do
        get  :diff
        post :merge
      end
    end

    resources :contact_password_policy, controller: 'ember/contact_password_policies',
                                        only: [:index]
    resources :agent_password_policy, controller: 'ember/agent_password_policies',
                                        only: [:index]

    resource :subscription, controller: 'admin/subscriptions', only: [:show]
    get '/plans', to: 'admin/subscriptions#plans'

    get '/yearin_review', to: 'ember/year_in_review#index'
    post '/yearin_review/share', to: 'ember/year_in_review#share'
    post '/yearin_review/clear', to: 'ember/year_in_review#clear'

    # Search routes

    post '/search/tickets/',      to: 'ember/search/tickets#results'
    post '/search/customers/',    to: 'ember/search/customers#results'
    post '/search/topics/',       to: 'ember/search/topics#results'
    
    post '/search/multiquery',    to: 'ember/search/multiquery#search_results'

    post '/search/autocomplete/requesters/',    to: 'ember/search/autocomplete#requesters'
    post '/search/autocomplete/agents/',        to: 'ember/search/autocomplete#agents'
    post '/search/autocomplete/companies/',     to: 'ember/search/autocomplete#companies'
    post '/search/autocomplete/tags/',          to: 'ember/search/autocomplete#tags'
  end

  pipe_routes = proc do
    resources :contacts, controller: 'pipe/api_contacts', only: [:create, :update]
    resources :tickets, controller: 'pipe/tickets', only: [:create, :update] do
      member do
        post :reply, to: 'pipe/conversations#reply'
        post :notes, to: 'pipe/conversations#create'
      end
    end
    get "/account/:account_id/info" => 'pipe/account_info#index', constraints: { account_id: /\d+/ }
    namespace :settings do
      resources :helpdesk, controller: 'pipe/helpdesk', only: [:index] do
        collection do
          put :toggle_email
          put :toggle_fast_ticket_creation
          put :change_api_v2_limit
        end
      end
    end
    resources :attachments, controller: 'ember/attachments', only: [:create, :show, :destroy] do
      member do
        put :unlink
      end
    end

    namespace :api_discussions, path: 'discussions' do
      resources :topics, controller: 'pipe/topics', only: [:create] do
        member do
          post :comments, to: 'pipe/api_comments#create'
        end
      end
      resources :forums, only: [:create] do
        member do
          post :topics, to: 'pipe/topics#create'
        end
      end
    end
  end

  channel_v2_routes = proc do
    resources :tickets, controller: 'channel/v2/tickets', only: [:index, :create, :update, :show] do
      member do
        post :reply, to: 'channel/v2/conversations#reply'
        post :notes, to: 'channel/v2/conversations#create'
      end
    end
    get '/account', to: 'channel/v2/accounts#show'
    resources :ticket_filters, controller: 'channel/v2/ticket_filters', only: [:index, :show]
  end

  channel_routes = proc do
    resources :freshcaller_calls, controller: 'channel/freshcaller/calls', only: %i[create update]
    delete '/freshcaller/account', to: 'channel/freshcaller/accounts#destroy'
    get '/freshcaller/contacts/:id/activities', to: 'channel/freshcaller/contacts#activities'
    post '/freshcaller/search/customers/', to: 'channel/freshcaller/search/customers#results'
    post '/freshcaller/search/tickets/', to: 'channel/freshcaller/search/tickets#results'
    post '/freshcaller/migration/validate', to: 'channel/freshcaller/migration#validate'
    post '/freshcaller/migration/initiate', to: 'channel/freshcaller/migration#initiate'
    post '/freshcaller/migration/cross_verify', to: 'channel/freshcaller/migration#cross_verify'
    post '/freshcaller/migration/revert', to: 'channel/freshcaller/migration#revert'
    post '/freshcaller/migration/reset_freshfone', to: 'channel/freshcaller/migration#reset_freshfone'
    post '/freshcaller/migration/fetch_pod_info', to: 'channel/freshcaller/migration#fetch_pod_info'

    resources :tickets, controller: 'channel/tickets', only: [:create]
    resources :contacts, as: 'api_contacts', controller: 'channel/api_contacts', only: [:create, :show, :index] do
      collection do
        get :fetch_contact_by_email
      end
    end
    resources :companies, controller: 'channel/api_companies', only: [:create]
    resources :attachments, controller: 'channel/attachments', only: [:create]
    scope '/v2' do
      resources :contacts, as: 'api_contacts', controller: 'channel/api_contacts', only: [:create, :index]
      resources :attachments, controller: 'channel/attachments', only: [:create, :show]
    end
    scope '/bot' do
      resources :tickets, controller: 'channel/bot/tickets', only: [:create]
    end
    match '/bots/:id/training_completed', to: 'channel/bot/services#training_completed', via: :post
  end

  widget_routes = proc do
    resources :tickets, controller: 'widget/tickets', only: [:create]
    resources :ticket_fields, controller: 'widget/ticket_fields', only: [:index]
  end

  scope '/api', defaults: { version: 'v2', format: 'json' }, constraints: { format: /(json|$^)/ } do
    scope '/v2', &api_routes # "/api/v2/.."
    scope '/_', defaults: { version: 'private', format: 'json' }, constraints: { format: /(json|$^)/ } do
      scope '', &ember_routes # "/api/v2/.."
      scope '', &api_routes # "/api/v2/.."
    end
    scope '/pipe', defaults: { version: 'pipe', format: 'json' }, constraints: { format: /(json|$^)/ } do
      scope '', &pipe_routes # "/api/v2/.."
      scope '', &api_routes # "/api/v2/.."
    end
    scope '/channel', defaults: { version: 'channel', format: 'json' }, constraints: { format: /(json|$^)/ } do
      scope '', &channel_routes # "/api/v2/.."
      scope '', &api_routes # "/api/v2/.."
      scope '/v2', &channel_v2_routes # "/api/channel/v2/.."
    end
    scope '/widget', defaults: { version: 'widget', format: 'json' }, constraints: { format: /(json|$^)/ } do
      scope '', &widget_routes # "/api/widget/.."
    end
    constraints ApiConstraints.new(version: 2), &api_routes # "/api/.." with Accept Header
    scope '', &api_routes
    match '*route_not_found.:format', to: 'api_application#route_not_found'
    match '*route_not_found',         to: 'api_application#route_not_found'
  end

  # Dev only routes
  match '/swagger/*path' => 'swagger#respond'
  match '/swagger' => 'swagger#respond'
end
