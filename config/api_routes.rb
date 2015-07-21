Helpkit::Application.routes.draw do
  api_routes = Proc.new do
    resources :tickets, :except => [:new, :edit] do
      member do
        put :assign
        put :restore
      end
    end
    resources :notes, :except => [:new, :edit, :show, :index]

    resources :ticket_fields, :controller => :api_ticket_fields, :only => [:index]

    resources :time_sheets, :except => [:new, :edit, :show] do 
      member do 
        put :toggle_timer
      end
    end

    match 'tickets/:ticket_id/reply' => 'notes#reply', :via => :post
    match 'tickets/:ticket_id/notes' => 'notes#ticket_notes', :via => :get
    match 'tickets/:ticket_id/time_sheets' => 'time_sheets#ticket_time_sheets', :via => :get

    namespace :api_discussions, :path => "discussions" do
      resources :categories, :except => [:new, :edit] do
        member do
          get :forums
        end
      end
      resources :forums, :except => [:new, :edit, :index] do
        member do
          get :topics
          post :follow, to: :follow
          delete :follow, to: :unfollow
          get :follow, to: :is_following
        end
      end
      resources :topics, :except => [:new, :edit, :index]do
        member do
          get :posts
          post :follow, to: :follow
          delete :follow, to: :unfollow
          get :follow, to: :is_following
        end
        collection do 
          get :followed_by
        end
      end
      resources :posts, :except => [:new, :edit, :index, :show]
    end
    resources :groups, as: "api_groups", :controller => "api_groups", :except => [:new, :edit]

    resources :products, :controller => "api_products", :only => [:index, :show]

    resources :email_configs, :controller => "api_email_configs", :only => [:index, :show]

    resources :business_calendars, :controller => "api_business_calendars", :only => [:index, :show]
  end
    
  scope "/api", defaults: {version: "v2", format: "json"}, :constraints => {:format => /(json|$^)/} do
    scope "/v2" , &api_routes # "/api/v2/.."
    constraints ApiConstraints.new(version: 1), &api_routes # "/api/.." with Accept Header
    scope "", &api_routes
    match "*route_not_found.:format", :to => "api_application#route_not_found"
    match "*route_not_found",         :to => "api_application#route_not_found"
  end
end