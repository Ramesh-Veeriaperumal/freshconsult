Helpkit::Application.routes.draw do
  api_routes = Proc.new do
    resources :tickets, :except => [:new, :edit] do
      member do
        put :restore
        get :time_entries, to: 'time_entries#ticket_time_entries'
        get :notes, to: 'notes#ticket_notes'
        post :reply, to: 'notes#reply'
        post :notes, to: 'notes#create'
        post :time_entries, to: 'time_entries#create'
      end
    end
    resources :notes, :except => [:new, :edit, :show, :index, :create]

    resources :ticket_fields, :controller => :api_ticket_fields, :only => [:index]

    resources :time_entries, :except => [:new, :edit, :show, :create] do 
      member do 
        put :toggle_timer
      end
    end

    namespace :api_discussions, :path => "discussions" do
      resources :categories, :except => [:new, :edit] do
        member do
          get :forums, to: 'forums#category_forums'
          post :forums, to: 'forums#create'
        end
      end
      resources :forums, :except => [:new, :edit, :index, :create] do
        member do
          get :topics, to: 'topics#forum_topics'
          post :follow, to: :follow
          delete :follow, to: :unfollow
          get :follow, to: :is_following
          post :topics, to: 'topics#create'
        end
      end
      resources :topics, :except => [:new, :edit, :index, :create]do
        member do
          get :posts, to: 'posts#topic_posts'
          post :follow, to: :follow
          delete :follow, to: :unfollow
          get :follow, to: :is_following
          post :posts, to: 'posts#create'
        end
        collection do 
          get :followed_by
        end
      end
      resources :posts, :except => [:new, :edit, :index, :show, :create]
    end
    resources :groups, as: "api_groups", :controller => "api_groups", :except => [:new, :edit]

    resources :contacts, as: "api_contacts", :controller => "api_contacts", :except => [:new, :edit] do
      member do
        put :make_agent
      end
    end

    resources :agents, :controller => "api_agents", :only => [:index, :show]

    resources :contact_fields, :controller => "api_contact_fields", :only => [:index]

    resources :products, :controller => "api_products", :only => [:index, :show]

    resources :email_configs, :controller => "api_email_configs", :only => [:index, :show]

    resources :business_calendars, :controller => "api_business_calendars", :only => [:index, :show]

    resources :companies, as: "api_companies", :controller => "api_companies", :except => [:new, :edit]

    resources :company_fields, as: "api_company_fields", :controller => "api_company_fields", :only => [:index]

    resources :sla_policies, :controller => "api_sla_policies", :only => [ :index, :update ]  
  end
    
  scope "/api", defaults: {version: "v2", format: "json"}, :constraints => {:format => /(json|$^)/} do
    scope "/v2" , &api_routes # "/api/v2/.."
    constraints ApiConstraints.new(version: 2), &api_routes # "/api/.." with Accept Header
    scope "", &api_routes
    match "*route_not_found.:format", :to => "api_application#route_not_found"
    match "*route_not_found",         :to => "api_application#route_not_found"
  end
end