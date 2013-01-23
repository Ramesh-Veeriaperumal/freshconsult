module Helpdesk
  module Roles

  ANONYMOUS = [
    :view_solutions,
    :view_forums,
  ]
    
  CUSTOMER = [
    :view_solutions,
    :view_forums,
    :create_forum_topic
  ]

  CUSTOMER_WITH_CLIENT_MANAGEMENT = [
    :view_solutions,
    :view_forums,
    :create_forum_topic,
    :client_manager
  ]


  ADMINISTRATOR = Authority::Authorization::PrivilegeList.privileges_by_name
  # ADMINISTRATOR = [
  #   :manage_account,
  #   :manage_users,
  #   :manage_tickets,
  #   :reply_ticket,
  #   :forward_ticket,
  #   :merge_or_split_ticket,
  #   :edit_ticket_properties,
  #   :edit_conversation,
  #   :edit_note,
  #   :view_time_entries,
  #   :edit_time_entries,
  #   :delete_ticket,
  #   :view_solutions,
  #   :publish_solution,
  #   :delete_solution,
  #   :create_edit_category_folder,
  #   :view_forums,
  #   :create_forum_topic,
  #   :edit_forum_content,
  #   :delete_forum_topic,
  #   :view_contacts,
  #   :add_or_edit_contact,
  #   :delete_contact,
  #   :view_reports,
  #   :view_admin,
  #   :manage_plan_billing,
  #   :manage_ticket_fields,
  #   :manage_canned_responses,
  #   :manage_email_settings,
  #   :manage_arcade_settings,
  #   :edit_sla_policy,
  #   :rebrand_helpdesk
  # ]

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
    :create_edit_category_folder,
    :view_forums,
    :create_forum_topic,
    :edit_forum_topic,
    :delete_forum_topic,
    :view_contacts,
    :add_or_edit_contact,
    :delete_contact,
    :view_reports
  ]
end
end