Helpkit::Application.routes.draw do
  api_routes = proc do
    resources :tickets, except: [:new, :edit] do
      collection do
        post :outbound_email, to: 'tickets#create', defaults: {_action: 'compose_email'}
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
      resources :topics, except: [:new, :edit, :index, :create]do
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

    resources :contacts, as: 'api_contacts', controller: 'api_contacts', except: [:new, :edit] do
      member do
        put :make_agent
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

    resources :contact_fields, controller: 'api_contact_fields', only: [:index]

    resources :products, controller: 'api_products', only: [:index, :show]

    resources :email_configs, controller: 'api_email_configs', only: [:index, :show]

    resources :business_hours, controller: 'api_business_hours', only: [:index, :show]

    resources :companies, as: 'api_companies', controller: 'api_companies', except: [:new, :edit]

    resources :company_fields, as: 'api_company_fields', controller: 'api_company_fields', only: [:index]

    resources :sla_policies, controller: 'api_sla_policies', only: [:index, :update]
  end
  
  ember_routes = proc do
    resources :ticket_fields, controller: 'ember/ticket_fields', only: [:index, :update]
    resources :bootstrap, controller: 'ember/bootstrap', only: :index
    resources :tickets, controller: 'ember/tickets', only: [:index, :destroy, :create] do
      collection do
        put :bulk_delete
        put :bulk_spam
        put :bulk_restore
        put :bulk_unspam
        put :bulk_update
      end
      member do
        put :spam
        put :restore
        put :unspam
        post :reply, to: 'ember/conversations#reply'
        post :notes, to: 'ember/conversations#create'
      end
      # This alternate route is to handle limitation in ember route generation : api/_/tickets/:ticket_id/canned_responses?id=Number
      match '/canned_responses' => 'ember/tickets/canned_responses#show', via: :get
      resources :canned_responses, controller: 'ember/tickets/canned_responses', only: [:show]

      member do
        post :watch, to: 'ember/subscriptions#watch'
        put :unwatch, to: 'ember/subscriptions#unwatch'
        get :watchers, to: 'ember/subscriptions#watchers'
      end
    end
    resources :contacts, controller: 'ember/contacts', except: [:new, :edit] do
      collection do
        put :bulk_delete
        put :bulk_restore
        put :bulk_send_invite
        put :bulk_whitelist
      end
      member do
        put :restore
        put :whitelist
        put :send_invite
        put :update_password
        get :activities
      end
    end
    resources :ticket_filters, controller: 'ember/ticket_filters', only: [:index, :show, :create, :update, :destroy]
    match '/tickets/bulk_execute_scenario/:scenario_id' => 'ember/tickets#bulk_execute_scenario', via: :put
    match '/tickets/:id/execute_scenario/:scenario_id' => 'ember/tickets#execute_scenario', via: :put
    resources :contact_fields, controller: 'ember/contact_fields', only: :index
    resources :scenario_automations, controller: 'ember/scenario_automations', only: :index
    resources :attachments, controller: 'ember/attachments', only: [:create]
    resources :canned_response_folders, controller: 'ember/canned_response_folders', only: [:index, :show]
  end

  match '/api/v2/_search/tickets' => 'tickets#search', :defaults => { :format => 'json' }, :as => :tickets_search, via: :get
  
  scope '/api', defaults: { version: 'v2', format: 'json' }, constraints: { format: /(json|$^)/ } do
    scope '/v2', &api_routes # "/api/v2/.."
    scope '/_', defaults: { version: 'private', format: 'json' }, constraints: { format: /(json|$^)/ } do
      scope '', &ember_routes # "/api/v2/.."
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
