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
        post :time_entries, to: 'time_entries#create'
      end
    end

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
        end
      end
      resources :comments, as: 'api_comments', controller: 'api_comments', only: [:destroy, :update]
    end
    resources :groups, as: 'api_groups', controller: 'api_groups', except: [:new, :edit]

    namespace :api_search, path: 'search' do
      resources :tickets, only: [:index]
    end

    resources :contacts, as: 'api_contacts', controller: 'api_contacts', except: [:new, :edit] do
      member do
        put :make_agent
        put :restore
      end
    end

    resources :agents, controller: 'api_agents', only: [:index, :show, :update, :destroy] do
      collection do
        get :me
      end
    end

    resources :surveys, only: [:index] do
      collection do
        get :satisfaction_ratings, to: 'satisfaction_ratings#index'
      end
    end

    resources :roles, controller: 'api_roles', only: [:index, :show]

    resources :roles, controller: 'api_roles', only: [:index, :show]

    namespace :settings do
      resources :helpdesk, only: [:index]
    end

    match 'export/ticket_activities' => 'export#ticket_activities', :defaults => { format: 'json' }, :as => :ticket_activities, via: :get

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

    resources :email_configs, controller: 'api_email_configs', only: [:index, :show]

    resources :business_hours, controller: 'api_business_hours', only: [:index, :show]

    resources :companies, as: 'api_companies', controller: 'api_companies', except: [:new, :edit]

    resources :company_fields, as: 'api_company_fields', controller: 'api_company_fields', only: [:index]

    namespace :api_integrations, path: 'integrations' do
      namespace :cti, path: 'cti' do
        post :pop, action: :create
        get :details, action: :index
      end
    end
    resources :sla_policies, controller: 'api_sla_policies', only: [:index, :update]
  end

  ember_routes = proc do
    resources :ticket_fields, controller: 'ember/ticket_fields', only: [:index, :update]
    resources :groups, controller: 'ember/groups', only: [:index, :show]
    resources :email_configs, controller: 'ember/email_configs', only: [:index, :show]
    resources :bootstrap, controller: 'ember/bootstrap', only: :index
    resources :tickets, controller: 'ember/tickets', only: [:index, :create, :update, :show] do
      collection do
        put :bulk_delete, to: 'ember/tickets/delete_spam#bulk_delete'
        put :bulk_spam, to: 'ember/tickets/delete_spam#bulk_spam'
        put :bulk_restore, to: 'ember/tickets/delete_spam#bulk_restore'
        put :bulk_unspam, to: 'ember/tickets/delete_spam#bulk_unspam'
        post :bulk_update, to: 'ember/tickets/bulk_actions#bulk_update'
        post :bulk_execute_scenario, to: 'ember/tickets/bulk_actions#bulk_execute_scenario'
        put :bulk_link, to: 'ember/tickets/bulk_actions#bulk_link'
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
        get :reply_template, to: 'ember/conversations#reply_template'
        post :forward, to: 'ember/conversations#forward'
        get :forward_template, to: 'ember/conversations#forward_template'
        post :broadcast, to: 'ember/conversations#broadcast'
        post :reply_to_forward, to: 'ember/conversations#reply_to_forward'

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
        match '/split_note/:note_id' => 'ember/tickets#split_note', via: :put
        # This alternate route is to handle limitation in ember route generation : api/_/tickets/:ticket_id/split_note?note_id=Number
        match '/split_note' => 'ember/tickets#split_note', via: :put
        post :facebook_reply, to: 'ember/conversations#facebook_reply'
        get :prime_association, to: 'ember/tickets/associates#prime_association'
        put :link, to: 'ember/tickets/associates#link'
        put :unlink, to: 'ember/tickets/associates#unlink'
        get :associated_tickets, to: 'ember/tickets/associates#associated_tickets'
      end
      resources :activities, controller: 'ember/tickets/activities', only: [:index]

      member do
        post :watch, to: 'ember/subscriptions#watch'
        put :unwatch, to: 'ember/subscriptions#unwatch'
        get :watchers, to: 'ember/subscriptions#watchers'
        put :update_properties, to: 'ember/tickets#update_properties'
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

    resources :todos, controller: 'ember/todos', except: [:new, :edit]
    resources :installed_applications, controller: 'ember/installed_applications', only: [:index, :show]
    resources :integrated_resources, controller: 'ember/integrated_resources', except: [:new, :edit]
    resources :integrated_users, controller: 'ember/integrated_users', only: [:index, :show]
    resources :cloud_files, controller: 'ember/cloud_files', only: [:destroy]

    resources :contacts, controller: 'ember/contacts', except: [:new, :edit] do
      collection do
        put :bulk_delete
        put :bulk_restore
        put :bulk_send_invite
        put :bulk_whitelist
        post :merge, to: 'ember/contacts/merge#merge'
        post :export_csv
        get :import, to: 'ember/customer_imports#index'
        post :import, to: 'ember/customer_imports#create'
        post :quick_create
      end
      member do
        put :restore
        put :whitelist
        put :send_invite
        put :update_password
        get :activities
        put :assume_identity
      end
    end

    resources :companies, controller: 'ember/companies', only: [:index, :show, :create, :update] do
      collection do
        put :bulk_delete
      end
      member do
        get :activities
      end
    end

    resources :attachments, controller: 'ember/attachments', only: [:create, :destroy] do
      member do
        put :unlink
      end
    end

    resources :ticket_filters, controller: 'ember/ticket_filters', only: [:index, :show, :create, :update, :destroy]
    resources :contact_fields, controller: 'ember/contact_fields', only: :index
    resources :company_fields, controller: 'ember/company_fields', only: :index
    resources :scenario_automations, controller: 'ember/scenario_automations', only: :index
    resources :canned_response_folders, controller: 'ember/canned_response_folders', only: [:index, :show]
    resources :canned_responses, controller: 'ember/canned_responses', only: [:show, :index] do
      collection do
        get :search
      end
    end

    resources :twitter_handles, controller: 'ember/twitter_handles', only: [:index] do
      member do
        get :check_following
      end
    end
    resources :surveys, controller: 'ember/surveys', only: [:index]
    resources :portals, controller: 'ember/portals', only: [:index]
    resources :agents, controller: 'ember/agents', only: [:index, :show, :update], id: /\d+/ do
      collection do
        get :me
      end
      member do
        get :achievements
      end
    end

    # dirty hack - check privilege fails when using 'solutions' namespace although controller action mapping is unaffected
    get 'solutions/articles', to: 'ember/solutions/articles#index'

    match '/dashboards/leaderboard_agents' => 'ember/leaderboard#agents', via: :get

    resources :marketplace_apps, controller: 'ember/marketplace_apps', only: [:index]

    resources :dashboards, controller: 'ember/dashboard', only: [:show] do
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

    # Search routes
    post '/search/tickets/',      to: 'ember/search/tickets#results'
    post '/search/customers/',    to: 'ember/search/customers#results'
    post '/search/topics/',       to: 'ember/search/topics#results'
    post '/search/solutions/',    to: 'ember/search/solutions#results'

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
    resources :attachments, controller: 'ember/attachments', only: [:create, :destroy] do
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

  channel_routes = proc do
    resources :tickets, controller: 'channel/tickets', only: [:create]
  end

  match '/api/v2/_search/tickets' => 'tickets#search', :defaults => { format: 'json' }, :as => :tickets_search, via: :get

  scope '/api', defaults: { version: 'v2', format: 'json' }, constraints: { format: /(json|$^)/ } do
    scope '/v2', &api_routes # "/api/v2/.."
    scope '/_', defaults: { version: 'private', format: 'json' }, constraints: { format: /(json|$^)/ } do
      scope '', &ember_routes # "/api/v2/.."
      scope '', &api_routes # "/api/v2/.."
    end
    scope '/pipe', defaults: { version: 'private', format: 'json' }, constraints: { format: /(json|$^)/ } do
      scope '', &pipe_routes # "/api/v2/.."
      scope '', &api_routes # "/api/v2/.."
    end
    scope '/channel', defaults: { version: 'private', format: 'json' }, constraints: { format: /(json|$^)/ } do
      scope '', &channel_routes # "/api/v2/.."
      scope '', &api_routes # "/api/v2/.."
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
