Authority::Authorization::PrivilegeList.build do
  manage_tickets do
    resource :"channel/v2/ticket", only: %i[index create update show]
    resource :"channel/v2/conversation", only: %i[create reply ticket_conversations]
    resource :"channel/v2/ticket_filter", only: %i[index show]
    resource :"channel/v2/ticket_misc", only: %i[index]
    resource :"channel/v2/tickets/bulk_action", only: %i[bulk_archive]
  end
  view_solutions do
    resource :"channel/v2/api_solutions/category", only: [:index, :show]
    resource :"channel/v2/api_solutions/folder", only: [:category_folders, :show, :index]
    resource :"channel/v2/api_solutions/article", only: [:folder_articles, :show, :index]
  end

  manage_account do
    resource :"channel/v2/account", only: [:show]
  end
  manage_contacts do
    resource :"channel/api_contact", only: [:create, :index, :show]
  end
end
