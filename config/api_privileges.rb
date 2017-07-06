Authority::Authorization::PrivilegeList.build do
  manage_tickets do
    resource :"ember/bootstrap"
    resource :"ember/tickets/delete_spam", only: %i(spam bulk_spam unspam bulk_unspam)
    resource :"ember/tickets/activity"
    resource :"ember/scenario_automation", only: [:index]
    resource :"ember/canned_response_folder", only: %i(index show)
    resource :"ember/canned_response", only: %i(show index search)
    resource :"ember/ticket", only: %i(index show create execute_scenario spam latest_note)
    resource :"ember/tickets/bulk_action", only: [:bulk_execute_scenario]
    resource :"ember/tickets/associate", only: [:link, :unlink, :associated_tickets, :prime_association]
    resource :"ember/ticket_filter", only: [:index, :show, :create, :update, :destroy]
    resource :"ember/attachment", only: [:create]
    resource :"ember/conversation", only: %i(create ticket_conversations full_text)
    resource :"ember/subscription"
    resource :"ember/ticket_field", only: [:index]
    resource :"ember/todo"
    resource :"ember/twitter_handles", only: %i(index check_following)

    resource :"ember/agent", only: %i(index me)
    resource :"ember/group", only: [:index]
    resource :"ember/survey", only: [:index]
    resource :"ember/portal", only: [:index]
    resource :"ember/email_config", only: [:index]
    resource :"ember/dashboard", only: %i(scorecard show survey_info)
    resource :"ember/contact_field", only: [:index]
    resource :"ember/installed_application"
    resource :"ember/integrated_resource"
    resource :"ember/integrated_user"


    resource :"ember/search/ticket", only: [:results]
    resource :"ember/search/autocomplete", only: %i(requesters agents companies tags)
    resource :"ember/leaderboard", only: [:agents]
  end

  reply_ticket do
    resource :"ember/conversation", only: %i(reply facebook_reply tweet reply_template)
    resource :"ember/tickets/draft", only: %i(save_draft show_draft clear_draft)
    resource :"ember/tickets/bulk_action", only: [:bulk_update]
  end

  forward_ticket do
    resource :"ember/conversation", only: %i(forward forward_template note_forward_template latest_note_forward_template)
  end

  merge_or_split_ticket do
    resource :"ember/tickets/merge", only: [:merge]
    resource :"ember/ticket", only: [:split_note]
  end

  edit_note do
    resource :"ember/conversation", only: [:update], owned_by: { scoper: :notes }
  end

  delete_contact do
    resource :"ember/contact", only: [:bulk_delete, :destroy, :bulk_restore, :restore, :whitelist, :bulk_whitelist]
    resource :"ember/company", only: [:bulk_delete, :destroy]
  end

  view_contacts do
    resource :"ember/contact", only: %i(index show)
    resource :"ember/company", only: %i(index show activities)

    resource :"ember/search/customer", only: [:results]
  end

  manage_contacts do
    resource :"ember/contact", only: [:create, :update, :activities]
    resource :"ember/company", only: [:create, :update]
    resource :"ember/contacts/merge", only: [:merge]

    resource :"ember/search/autocomplete", only: [:companies]
  end

  manage_users do
    resource :"ember/contact", only: %i(make_agent send_invite bulk_send_invite)
    resource :"ember/agent", only: [:show]
  end

  delete_topic do
    resource :"ember/dashboard", only: [:moderation_count]
  end

  manage_availability do
    resource :"ember/group", only: [:show]
  end

  delete_ticket do
    resource :"ember/tickets/delete_spam", only: %i(empty_trash empty_spam delete_forever destroy bulk_delete restore bulk_restore)
  end

  admin_tasks do
    resource :"ember/contact", only: [:update_password]
  end

  edit_ticket_properties do
    resource :"ember/ticket", only: %i(update update_properties)
    resource :"ember/tickets/bulk_action", only: [:bulk_update]
  end

  view_time_entries do
    resource :"ember/time_entry", only: %i(index create ticket_time_entries show)
  end

  edit_time_entries do
    resource :"ember/time_entry", only: %i(update destroy toggle_timer), owned_by: { scoper: :time_sheets }
  end

  export_customers do
    resource :"ember/contact", only: [:export_csv]
  end

  export_tickets do
    resource :"ember/ticket", :only => [:export_csv]
  end

  view_forums do
    resource :"ember/search/topic", only: [:results]
  end

  view_solutions do
    resource :"ember/search/solution", only: [:results]
  end

  view_reports do
    resource :"ember/dashboard", only: %i(unresolved_tickets_data ticket_trends ticket_metrics)
  end
end
