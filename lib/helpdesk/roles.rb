module Helpdesk
  module Roles
    
    def default_roles
    [  
      [ "Account Administrator",
        ACCOUNT_ADMINISTRATOR,
        "Has complete control over the help desk including access to Account or Billing
         related information, and receives Invoices."],
      
      [ "Administrator",
        ADMINISTRATOR,
        "Can configure all features through the Admin tab, but is restricted from viewing
         Account or Billing related information."],
      
      [ "Supervisor",
        SUPERVISOR,
        "Can perform all agent related activities and access reports, but cannot access or
         change configurations in the Admin tab."],
      
      [ "Agent",
        AGENT,
        "Can log, view, reply, update and resolve tickets and manage contacts."],
      
      [ "Restricted Agent",
        RESTRICTED_AGENT,
        "Can log, view, reply, update and resolve tickets, but cannot view or edit contacts."]
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