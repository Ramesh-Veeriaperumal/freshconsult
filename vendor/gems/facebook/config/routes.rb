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

  match '/social/facebook', controller: 'admin/social/facebook_streams#index', via: :get

  filter :facebook
end
