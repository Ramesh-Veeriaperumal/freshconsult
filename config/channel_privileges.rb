Authority::Authorization::PrivilegeList.build do
  manage_tickets do
    resource :"channel/ticket", only: [:create]
    resource :"channel/bot/ticket", only: [:create]
    resource :"channel/freshcaller/call", only: %i[create update]  
  end
end
