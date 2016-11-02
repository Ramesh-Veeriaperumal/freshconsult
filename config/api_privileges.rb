Authority::Authorization::PrivilegeList.build do
  manage_tickets do
    resource :"ember/bootstrap"
    resource :"ember/ticket", only: [:create, :index, :spam, :bulk_spam, :unspam, :bulk_unspam, 
                                      :execute_scenario, :bulk_execute_scenario]
    resource :"ember/scenario_automation", only: [:index]
    resource :"ember/canned_response_folder", only: [:index, :show]
    resource :"ember/tickets/canned_response", only: [:show]
    resource :"ember/ticket", only: [:index, :spam, :latest_note]
    resource :"ember/ticket_filter", only: [:index, :show, :create, :update, :destroy]
    resource :"ember/attachment", only: [:create]
    resource :"ember/conversation", only: [:create]
    resource :"ember/subscription"
    resource :"ember/ticket_field", only: [:index]
  end

  reply_ticket do
    resource :"ember/conversation", only: [:reply]
  end

  forward_ticket do
    resource :"ember/conversation", only: [:forward]
  end
 
  merge_or_split_ticket do
    resource :"ember/tickets/merge", only: [:merge]
    resource :"ember/ticket", only: [:split_note]
  end

  delete_contact do
    resource :"ember/contact", only: [:bulk_delete, :destroy, :bulk_restore, :restore, :whitelist, :bulk_whitelist]
  end

  view_contacts do
    resource :"ember/contact", only: [:index, :show]
  end

  manage_contacts do
    resource :"ember/contact", only: [:create, :update, :activities]
  end

  manage_users do
    resource :"ember/contact", only: [:make_agent, :send_invite, :bulk_send_invite]
  end

	delete_ticket do
		resource :"ember/ticket", only: [:destroy, :bulk_delete, :restore, :bulk_restore]
	end

  admin_tasks do
    resource :"ember/contact", only: [:update_password]
  end

  edit_ticket_properties do
    resource :"ember/ticket", only: [:bulk_update]
  end

  view_time_entries do
    resource :"ember/time_entry", :only => [:index, :create, :ticket_time_entries, :show]
  end

  edit_time_entries do
    resource :"ember/time_entry", :only => [:update, :destroy, :toggle_timer], :owned_by =>
      { :scoper => :time_sheets }
  end

end
