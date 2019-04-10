Authority::Authorization::PrivilegeList.build do
  manage_tickets do
    resource :"channel/ticket", only: [:create]
    resource :"channel/bot/ticket", only: [:create]
  end

  manage_contacts do
  	resource :"channel/api_contact", only: [:create]
  end

  manage_companies do
    resource :"channel/api_company", only: [:create]
  end
end
