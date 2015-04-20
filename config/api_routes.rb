Helpkit::Application.routes.draw do

  api_routes = Proc.new do
    scope :format => true, :constraints => { :format => 'json' } do
      namespace :api_discussions, :path => "discussions" do
        resources :categories, :except => [:new, :edit]
      end
    end
  end
    
  scope "/api", defaults: {version: 2} do
    scope "/v2" , &api_routes # "/api/v2/.."
    constraints ApiConstraints.new(version: 1), &api_routes # "/api/.." with Accept Header
    scope "", &api_routes
  end


end