Authority::Authorization::PrivilegeList.build do
  manage_tickets do
    resource :"channel/ticket", only: [:create]
  end
end
