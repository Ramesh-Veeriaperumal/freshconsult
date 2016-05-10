Rails.application.routes.draw do  

  namespace :admin do
    namespace :social do
      
      resources :facebook_streams       
      
      resources :facebook_pages, :only => [:destroy] do
        collection do
          put :enable_pages
        end
      end  
      
      resources :tabs, :controller => :facebook_tabs do
        member do
          delete :remove
        end
      end
          
    end
  end
  
  namespace :social do   
    resources :facebook, :controller => 'facebook_pages'  do
      collection do
        put  :enable_pages
        post :update_page_token
      end
      member do
        get :edit
      end 
    end
  end
  
  filter :facebook

  namespace :support do
    match '/facebook_tab/redirect/:app_id' => 'facebook_tabs#redirect', :as => :facebook_tab_home, :app_id => nil
  end
end
