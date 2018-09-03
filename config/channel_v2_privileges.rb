Authority::Authorization::PrivilegeList.build do
  manage_tickets do
    resource :"channel/v2/ticket", only: %i[create update]
    resource :"channel/v2/conversation", only: %i[create reply]
  end
end
