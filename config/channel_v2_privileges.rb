Authority::Authorization::PrivilegeList.build do
  manage_tickets do
    resource :"channel/v2/ticket", only: %i[index create update show]
    resource :"channel/v2/conversation", only: %i[create reply ticket_conversations]
    resource :"channel/v2/ticket_filter", only: %i[index show]
    resource :"channel/v2/ticket_misc", only: %i[index]
    resource :"channel/v2/tickets/bulk_action", only: %i[bulk_archive]
    resource :"channel/v2/agent", only: [:verify_agent_privilege]
  end
  view_solutions do
    resource :"channel/v2/api_solutions/category", only: [:index, :show]
    resource :"channel/v2/api_solutions/folder", only: [:category_folders, :show, :index]
    resource :"channel/v2/api_solutions/article", only: [:folder_articles, :show, :index]
  end

  manage_account do
    resource :"channel/v2/account", only: [:show, :update_freshchat_domain]
  end
  manage_contacts do
    resource :"channel/api_contact", only: [:create, :index, :show]
  end
  manage_users do
    resource :"channel/v2/agent", only: [:create, :update_multiple]
  end
  manage_canned_responses do
    resource :"channel/v2/canned_response", only: [:create]
  end

  edit_note do
    resource :"channel/v2/conversation", only: [:update], owned_by: { scoper: :notes }
  end
end
