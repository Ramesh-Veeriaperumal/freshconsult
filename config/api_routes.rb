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

    namespace :api_integrations, :path => "integrations" do
      namespace :cti, :path => "cti" do
        post :pop, :action => :create
        get :details, :action => :index
      end
    end
    resources :sla_policies, controller: 'api_sla_policies', only: [:index, :update]
  end

  pipe_routes = proc do 
    resources :contacts, controller: 'pipe/api_contacts', only: [:create, :update]
    resources :tickets, controller: 'pipe/tickets', only: [:create, :update] do
      member do
        post :reply, to: 'pipe/conversations#reply'
        post :notes, to: 'pipe/conversations#create'
      end
    end
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
end
