Authority::Authorization::PrivilegeList.build do
  manage_tickets do
    resource :"pipe/ticket", only: [:create]
    resource :"pipe/conversation", only: [:create]
  end
end
