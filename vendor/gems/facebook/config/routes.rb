Rails.application.routes.draw do

  namespace :social do
    resources :facebook, :controller => 'facebook_pages'  do
      collection do
        post :signin
        post :event_listener
        put :enable_pages
        post :update_page_token
      end
      member do
        get :edit
      end
      resources :tabs, :controller => :facebook_tabs do
        collection do
          post :configure
          delete :remove
        end
      end
    end
    match 'facebook' => 'facebook_pages#index', :as => :filter
  end  

  filter :facebook

  namespace :support do
      match '/facebook_tab/redirect/:app_id' => 'facebook_tabs#redirect', :as => :facebook_tab_home, :app_id => nil
  end
end
