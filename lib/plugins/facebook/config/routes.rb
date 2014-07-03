ActionController::Routing::Routes.draw do |map|

  map.namespace :social do |social|
    social.resources :facebook, :controller => 'facebook_pages',
      :collection =>  { :signin => :any , :event_listener =>:any , :enable_pages =>:any, :update_page_token => :any },
      :member     =>  { :edit => :any } do |fb|
         fb.resources :tabs, :controller => 'facebook_tabs',
        :collection => { :configure => :any, :remove => :any }
    end
    
    #uncomment it before running the spec locally
    #social.resources :realtime, :controller => 'facebook_subscription',
    #:only => :none, :collection => {:subscription => [:get,:post]}
  end

  map.filter 'facebook'
  
  map.namespace :support do |support|
    support.facebook_tab_home "/facebook_tab/redirect/:app_id", :controller => 'facebook_tabs', 
      :action => :redirect, :app_id => nil
  end
end
