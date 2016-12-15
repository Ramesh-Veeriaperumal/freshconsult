Authority::Authorization::PrivilegeList.build do
  manage_tickets do
    resource :"ember/bootstrap"
    resource :"ember/tickets/delete_spam", only: [:spam, :bulk_spam, :unspam, :bulk_unspam]
    resource :"ember/ticket/activity"
    resource :"ember/scenario_automation", only: [:index]
    resource :"ember/canned_response_folder", only: [:index, :show]
    resource :"ember/canned_response", only: [:show]
    resource :"ember/tickets/canned_response", only: [:show]
    resource :"ember/ticket", only: [:index, :show, :create, :execute_scenario, :bulk_execute_scenario, :spam, :latest_note]
    resource :"ember/ticket_filter", only: [:index, :show, :create, :update, :destroy]
    resource :"ember/attachment", only: [:create]
    resource :"ember/conversation", only: [:create, :ticket_conversations]
    resource :"ember/subscription"
    resource :"ember/ticket_field", only: [:index]
    resource :"ember/todo"
    resource :"ember/twitter_handles", only: [:index, :check_following]
  end

  reply_ticket do
    resource :"ember/conversation", only: [:reply, :facebook_reply, :tweet, :reply_template]
    resource :"ember/tickets/draft", only: [:save_draft, :show_draft, :clear_draft]
  end

  forward_ticket do
    resource :"ember/conversation", only: [:forward, :forward_template]
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
    resource :"ember/company", only: [:index, :show, :activities]
  end

  manage_contacts do
    resource :"ember/contact", only: [:create, :update, :activities]
    resource :"ember/contacts/merge", only: [:merge]
  end

  manage_users do
    resource :"ember/contact", only: [:make_agent, :send_invite, :bulk_send_invite]
  end

	delete_ticket do
    resource :"ember/tickets/delete_spam", only: [:empty_trash, :empty_spam, :delete_forever, :destroy, :bulk_delete, :restore, :bulk_restore]
	end

  admin_tasks do
    resource :"ember/contact", only: [:update_password]
  end

  edit_ticket_properties do
    resource :"ember/ticket", only: [:bulk_update, :update_properties]
  end

  view_time_entries do
    resource :"ember/time_entry", :only => [:index, :create, :ticket_time_entries, :show]
  end

  edit_time_entries do
    resource :"ember/time_entry", :only => [:update, :destroy, :toggle_timer], :owned_by =>
      { :scoper => :time_sheets }
  end

  export_customers do
    resource :"ember/contact", only: [:export_csv]
  end
end
