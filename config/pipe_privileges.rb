Authority::Authorization::PrivilegeList.build do
  manage_contacts do
    resource :"pipe/api_contact", only: [:create, :update]
  end

  manage_tickets do
    resource :"pipe/ticket", only: [:create, :update]
    resource :"pipe/conversation", only: [:create]
  end

  view_forums do
  	resource :"api_discussions/pipe/api_comment", :only => [:create, :topic_comments]
  end

  create_topic do
  	resource :"api_discussions/pipe/topic", :only => [:create]
  end

  admin_tasks do
    resource :"settings/pipe/helpdesk", :only => [:index, :toggle_email]
  end  
end
