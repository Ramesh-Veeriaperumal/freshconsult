Helpkit::Application.routes.draw do

  api_routes = Proc.new do
    namespace :api_discussions, :path => "discussions" do
      resources :categories, :except => [:new, :edit]
      resources :forums, :except => [:new, :edit, :index]
      resources :topics, :except => [:new, :edit, :index]
    end
  end
    
  scope "/api", defaults: {version: "v2", format: "json"}, :constraints => {:format => /(json|$^)/} do
    scope "/v2" , &api_routes # "/api/v2/.."
    constraints ApiConstraints.new(version: 1), &api_routes # "/api/.." with Accept Header
    scope "", &api_routes
    match "*route_not_found.:format", :to => "api_application#route_not_found"
    match "*route_not_found",         :to => "api_application#route_not_found"
  end


end