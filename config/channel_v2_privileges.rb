Authority::Authorization::PrivilegeList.build do
  manage_tickets do
    resource :"channel/v2/ticket", only: %i[index create update show]
    resource :"channel/v2/conversation", only: %i[create reply]
    resource :"channel/v2/ticket_filter", only: %i[index show]
  end
  manage_account do
    resource :"channel/v2/account", only: [:show]
  end
end
