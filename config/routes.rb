ActionController::Routing::Routes.draw do |map|
  map.logout '/logout', :controller => 'sessions', :action => 'destroy'
  map.login '/login', :controller => 'sessions', :action => 'new'
  map.register '/register', :controller => 'users', :action => 'create'
  map.signup '/signup', :controller => 'users', :action => 'new'
  map.resources :users

  map.resource :session


  # Restful-authentication routes. Not to be included in final engine.  map.resource :session

  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller
  
  # Sample resource route with more complex sub-resources
  #   map.resources :products do |products|
  #     products.resources :comments
  #     products.resources :sales, :collection => { :recent => :get }
  #   end

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  # map.root :controller => "welcome"

  # See how all your routes lay out with "rake routes"

  # Begin routes to be included in final engine
  
  # The reason for the strange name_prefix values is that when you pass a Helpdesk::Ticket
  # instance to url_for, it will look for the named path called "helpdesk_ticket". So if 
  # you pass in [@ticket, @note] it will look for helpdesk_ticket_helpdesk_note, etc.
  map.namespace :helpdesk do |helpdesk|

    helpdesk.resources :tags, :collection => { :autocomplete => :get }

    helpdesk.resources :issues, :collection => {:empty_trash => :delete}, :member => { :delete_all => :delete, :assign => :put, :restore => :put, :restore_all => :put } do |ticket|
      ticket.resources :notes, :member => { :restore => :put }, :name_prefix => 'helpdesk_issue_helpdesk_'
    end

    helpdesk.resources :tickets, :collection => {:empty_trash => :delete, :empty_spam => :delete}, :member => { :assign => :put, :restore => :put, :spam => :put, :unspam => :put } do |ticket|
      ticket.resources :notes, :member => { :restore => :put }, :name_prefix => 'helpdesk_ticket_helpdesk_'
      ticket.resources :subscriptions, :name_prefix => 'helpdesk_ticket_helpdesk_'
      ticket.resources :tag_uses, :name_prefix => 'helpdesk_ticket_helpdesk_'
      ticket.resources :reminders, :name_prefix => 'helpdesk_ticket_helpdesk_'
    end

    helpdesk.resources :ticket_issues

    helpdesk.resources :notes

    helpdesk.resources :reminders, :member => { :restore => :put }

    helpdesk.filter_tag_tickets '/tags/:id/*filters', :controller => 'tags', :action => 'show'
    helpdesk.filter_tickets '/tickets/filter/*filters', :controller => 'tickets', :action => 'index'

    helpdesk.filter_issues '/issues/filter/*filters', :controller => 'issues', :action => 'index'

    helpdesk.formatted_dashboard '/dashboard.:format', :controller => 'dashboard', :action => 'index'
    helpdesk.dashboard '', :controller => 'dashboard', :action => 'index'


    helpdesk.resources :articles, :collection => { :autocomplete => :get }

    helpdesk.resources :article_guides

    helpdesk.resources :attachments

    helpdesk.resources :guides, :member => { :reorder_articles => :put, :privatize => :put, :publicize => :put }, :collection => { :reorder => :put }
    
    helpdesk.resources :authorizations, :collection => { :autocomplete => :get }
  end

  map.namespace :support do |support|
    support.resources :guides, :articles
    support.resources :tickets do |ticket|
      ticket.resources :notes, :name_prefix => 'support_ticket_helpdesk_'
    end
    support.resources :minimal_tickets
    support.map '', :controller => 'guides', :action => 'index'
  end

  map.connect '', :controller => 'helpdesk/dashboard', :action => 'index'

  # End routes to be included in final engine

  # Install the default routes as the lowest priority.
  # Note: These default routes make all actions in every controller accessible via GET requests. You should
  # consider removing the them or commenting them out if you're using named routes and resources.
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
end
