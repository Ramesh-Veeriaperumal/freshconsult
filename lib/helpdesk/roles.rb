module Helpdesk
  module Roles
    
    def default_roles_list
    [  
      ["Account Administrator", ACCOUNT_ADMINISTRATOR, "Account Administrator"],
      ["Administrator",         ADMINISTRATOR,         "Administrator"],
      ["Supervisor",            SUPERVISOR,            "Supervisor"],
      ["Agent",                 AGENT,                 "Agent"]
    ]
    end
        
    ACCOUNT_ADMINISTRATOR = [
      :manage_tickets,
      :reply_ticket,
      :forward_ticket,
      :merge_or_split_ticket,
      :edit_ticket_properties,
      :edit_conversation,
      :edit_note,
      :view_time_entries,
      :edit_time_entries,
      :delete_ticket,
      :view_solutions,
      :publish_solution,
      :delete_solution,
      :manage_solutions,
      :view_forums,
      :manage_forums,
      :create_topic,
      :edit_topic,
      :delete_topic,
      :view_contacts,
      :manage_contacts,
      :delete_contact,
      :view_reports,
      :view_admin,
      :manage_users,
      :manage_canned_responses,
      :manage_dispatch_rules,
      :manage_supervisor_rules,
      :manage_scenario_automation_rules,
      :manage_email_settings,
      :admin_tasks,
      :manage_account
    ]
    
    ADMINISTRATOR = [
      :manage_tickets,
      :reply_ticket,
      :forward_ticket,
      :merge_or_split_ticket,
      :edit_ticket_properties,
      :edit_conversation,
      :edit_note,
      :view_time_entries,
      :edit_time_entries,
      :delete_ticket,
      :view_solutions,
      :publish_solution,
      :delete_solution,
      :manage_solutions,
      :view_forums,
      :manage_forums,
      :create_topic,
      :edit_topic,
      :delete_topic,
      :view_contacts,
      :manage_contacts,
      :delete_contact,
      :view_reports,
      :view_admin,
      :manage_users,
      :manage_canned_responses,
      :manage_dispatch_rules,
      :manage_supervisor_rules,
      :manage_scenario_automation_rules,
      :manage_email_settings,
      :admin_tasks
    ]
    
    SUPERVISOR = [
      :manage_tickets,
      :reply_ticket,
      :forward_ticket,
      :merge_or_split_ticket,
      :edit_ticket_properties,
      :edit_conversation,
      :edit_note,
      :view_time_entries,
      :edit_time_entries,
      :delete_ticket,
      :view_solutions,
      :publish_solution,
      :delete_solution,
      :manage_solutions,
      :view_forums,
      :manage_forums,
      :create_topic,
      :edit_topic,
      :delete_topic,
      :view_contacts,
      :manage_contacts,
      :delete_contact,
      :view_reports
    ]
    
    AGENT = [
      :manage_tickets,
      :reply_ticket,
      :forward_ticket,
      :merge_or_split_ticket,
      :edit_ticket_properties,
      :edit_conversation,
      :edit_note,
      :view_time_entries,
      :edit_time_entries,
      :delete_ticket,
      :view_solutions,
      :publish_solution,
      :delete_solution,
      :manage_solutions,
      :view_forums,
      :create_topic,
      :edit_topic,
      :delete_topic,
      :view_contacts,
      :manage_contacts,
      :delete_contact
    ]
    
    
    RESTRICTED_AGENT = [
      :manage_tickets,
      :reply_ticket,
      :forward_ticket,
      :merge_or_split_ticket,
      :edit_ticket_properties,
      :edit_conversation,
      :edit_note,
      :view_time_entries,
      :edit_time_entries,
      :delete_ticket,
      :view_solutions,
      :publish_solution,
      :delete_solution,
      :manage_solutions,
      :view_forums,
      :create_topic,
      :edit_topic,
      :delete_topic
    ]
  end
end