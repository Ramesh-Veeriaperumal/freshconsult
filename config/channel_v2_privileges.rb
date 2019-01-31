Authority::Authorization::PrivilegeList.build do
  manage_tickets do
    resource :"channel/v2/ticket", only: %i[index create update show]
    resource :"channel/v2/conversation", only: %i[create reply]
    resource :"channel/v2/ticket_filter", only: %i[index show]
    resource :"channel/v2/ticket_misc", only: %i[index]
  end
  view_solutions do
    resource :"channel/v2/api_solutions/category", only: [:index, :show]
    resource :"channel/v2/api_solutions/folder", only: [:category_folders, :show, :index]
    resource :"channel/v2/api_solutions/article", only: [:folder_articles, :show, :index]
  end

  manage_account do
    resource :"channel/v2/account", only: [:show]
  end
end
