ActionController::Routing::Routes.draw do |map|
  map.resources :posts, :name_prefix => 'all_', :collection => { :search => :get }
	map.resources :forums, :topics, :posts, :monitorship

  %w(forum).each do |attr|
    map.resources :posts, :name_prefix => "#{attr}_", :path_prefix => "/#{attr.pluralize}/:#{attr}_id"
  end
  
  #map.resources :forums do |forum|
   # forum.resources :topics do |topic|
    #  topic.resources :posts
     # topic.resource :monitorship, :controller => :monitorships
    #end
  #end

 map.resources :categories, :collection => {:reorder => :put}, :controller=>'forum_categories'  do |forum_c|
  forum_c.resources :forums, :collection => {:reorder => :put} do |forum|
    forum.resources :topics, :member => { :users_voted => :get, :update_stamp => :put,:remove_stamp => :put, :update_lock => :put }
    forum.resources :topics do |topic|
      topic.resources :posts, :member => { :toggle_answer => :put } 
      topic.resource :monitorship, :controller => :monitorships
      end
    end
  end

# screws up default / defined by the application    
#  map.forum_home '', :controller => 'forums', :action => 'index'
end