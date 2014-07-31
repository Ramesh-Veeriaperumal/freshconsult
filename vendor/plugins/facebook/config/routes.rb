Rails.application.routes.draw do

  namespace :social do
    resources :facebook do
      collection do
        post :signin
        post :event_listener
        post :enable_pages
        post :update_page_token
      end
      member do
        get :edit
      end
      resources :tabs do
        collection do
          post :configure
          delete :remove
        end
      end
    end
  end

  # TODO-RAILS3 need to cross check
  # match 'facebook' => '#index', :as => :filter

  namespace :support do
      match '/facebook_tab/redirect/:app_id' => 'facebook_tabs#redirect', :as => :facebook_tab_home, :app_id => nil
  end
end
