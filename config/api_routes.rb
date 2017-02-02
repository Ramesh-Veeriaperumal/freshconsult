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

  ember_routes = proc do
    resources :ticket_fields, controller: 'ember/ticket_fields', only: [:index, :update]
    resources :bootstrap, controller: 'ember/bootstrap', only: :index
    resources :tickets, controller: 'ember/tickets', only: [:index, :create, :show] do
      collection do
        put :bulk_delete, to: 'ember/tickets/delete_spam#bulk_delete'
        put :bulk_spam, to: 'ember/tickets/delete_spam#bulk_spam'
        put :bulk_restore, to: 'ember/tickets/delete_spam#bulk_restore'
        put :bulk_unspam, to: 'ember/tickets/delete_spam#bulk_unspam'
        post :bulk_update, to: 'ember/tickets/bulk_actions#bulk_update'
        post :bulk_execute_scenario, to: 'ember/tickets/bulk_actions#bulk_execute_scenario'
        put :merge, to: 'ember/tickets/merge#merge'
        delete :empty_trash, to: 'ember/tickets/delete_spam#empty_trash'
        delete :empty_spam, to: 'ember/tickets/delete_spam#empty_spam'
        put :delete_forever, to: 'ember/tickets/delete_spam#delete_forever'
        put :bulk_watch, to: 'ember/subscriptions#bulk_watch'
        put :bulk_unwatch, to: 'ember/subscriptions#bulk_unwatch'
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
      end
      # This alternate route is to handle limitation in ember route generation : api/_/tickets/:ticket_id/canned_responses?id=Number
      match '/canned_responses' => 'ember/tickets/canned_responses#show', via: :get
      resources :canned_responses, controller: 'ember/tickets/canned_responses', only: [:show]
      resources :activities, controller: 'ember/tickets/activities', only: [:index]

      member do
        post :watch, to: 'ember/subscriptions#watch'
        put :unwatch, to: 'ember/subscriptions#unwatch'
        get :watchers, to: 'ember/subscriptions#watchers'
        put :update_properties, to: 'ember/tickets#update_properties'
      end
      # This alternate route is to handle limitation in ember route generation : api/_/tickets/:ticket_id/canned_responses?id=Number
      match '/canned_responses' => 'ember/tickets/canned_responses#show', via: :get
      resources :canned_responses, controller: 'ember/tickets/canned_responses', only: [:show]
    end

    resources :time_entries, controller: 'ember/time_entries', except: [:new, :edit, :create] do
      member do
        put :toggle_timer
      end
    end

    resources :conversations, controller: 'ember/conversations', only: [:update] do
      member do
        get :full_text
      end
    end

    resources :todos, controller: 'ember/todos', except: [:new, :edit]
    resources :installed_applications, controller: 'ember/installed_applications', only: [:index, :show]
    resources :integrated_resources, controller: 'ember/integrated_resources', only: [:index, :show]


    resources :contacts, controller: 'ember/contacts', except: [:new, :edit] do
      collection do
        put :bulk_delete
        put :bulk_restore
        put :bulk_send_invite
        put :bulk_whitelist
        post :merge, to: 'ember/contacts/merge#merge'
        post :export_csv
      end
      member do
        put :restore
        put :whitelist
        put :send_invite
        put :update_password
        get :activities
      end
    end

    resources :companies, controller: 'ember/companies', only: [:index, :show] do
      member do
        get :activities
      end
    end

    resources :ticket_filters, controller: 'ember/ticket_filters', only: [:index, :show, :create, :update, :destroy]
    resources :contact_fields, controller: 'ember/contact_fields', only: :index
    resources :scenario_automations, controller: 'ember/scenario_automations', only: :index
    resources :attachments, controller: 'ember/attachments', only: [:create, :destroy]
    resources :canned_response_folders, controller: 'ember/canned_response_folders', only: [:index, :show]
    resources :canned_responses, controller: 'ember/canned_responses', only: [:show, :index]
    
    resources :twitter_handles, controller: 'ember/twitter_handles', only: [:index] do
      member do
        get :check_following
      end
    end
    resources :surveys, controller: 'ember/surveys', only: [:index]
    resources :agents, controller: 'ember/agents', only: [:index, :show] do
      collection do
        get :me
      end
    end
  end

  match '/api/v2/_search/tickets' => 'tickets#search', :defaults => { format: 'json' }, :as => :tickets_search, via: :get

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
