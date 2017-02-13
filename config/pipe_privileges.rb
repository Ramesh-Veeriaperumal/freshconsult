Authority::Authorization::PrivilegeList.build do
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
end
