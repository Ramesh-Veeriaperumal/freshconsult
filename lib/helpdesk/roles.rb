module Helpdesk
  module Roles

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
      :spam_ticket,
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
      :manage_availability,
      :manage_canned_responses,
      :manage_dispatch_rules,
      :manage_supervisor_rules,
      :manage_scenario_automation_rules,
      :manage_email_settings,
      :admin_tasks,
      :manage_account,
      :export_tickets,
      :edit_private_note,
      :assign_agent,
      :assign_group,
      :import_customers,
      :export_customers,
      :manage_ticket_templates,
      :manage_skills,
      :edit_ticket_skill,
      :export_reports,
      :create_solution_draft,
      :manage_ticket_list_views,
      :compose_email,
      :manage_customer_list,
      :solution_view_reports,
      :solution_exports,
      :forums_view_reports,
      :forums_exports,
      :forums_admin_moderator,
      :solution_delete_versions,
      :solution_restore_versions,
      :solution_view_versions,
      :forum_advanced_moderator,
      :forum_basic_moderator,
      :untitled_core_acc_admin_1,
      :untitled_core_acc_admin_2,
      :untitled_core_acc_admin_3,
      :untitled_core_acc_admin_4,
      :untitled_core_acc_admin_5,
      :manage_tags,
      :manage_bots,
      :manage_segments,
      :manage_proactive_outreaches,
      :untitled_core_supervisor_1,
      :untitled_core_supervisor_2,
      :untitled_core_supervisor_3,
      :untitled_core_supervisor_4,
      :untitled_core_supervisor_5,
      :untitled_core_supervisor_6,
      :create_tags,
      :view_bots,
      :untitled_core_agent_3,
      :untitled_core_agent_4,
      :untitled_core_agent_5,
      :untitled_solution_admin_1,
      :untitled_forums_admin_1,
      :untitled_solution_supervisor_1,
      :untitled_solution_supervisor_2,
      :untitled_forums_supervisor_1,
      :untitled_forums_supervisor_2,
      :untitled_solution_agent_1,
      :untitled_solution_agent_2,
      :untitled_solution_agent_3,
      :untitled_forum_agent_1,
      :untitled_forum_agent_2,
      :untitled_forum_agent_3,
      :view_social,                           #Social_privileges
      :social_convert_to_ticket,
      :social_reply_and_compose_post,
      :manage_social_response,
      :phone_attend_call,                     #FreshFone_privileges
      :phone_make_call,
      :phone_export_call_history,
      :livechat_admin_tasks,                  #LiveChat_privileges
      :livechat_manage_visitor,
      :livechat_view_transcripts,
      :livechat_edit_transcripts,
      :livechat_delete_transcripts,
      :livechat_accept_chat,
      :livechat_initiat_agent_chat,
      :livechat_view_visitors,
      :livechat_intiate_visitor_chat,
      :livechat_shadow_chat,
      :livechat_export_transcripts,
      :livechat_manage_shortcodes,
      :livechat_view_reports,
      :manage_calls,
      :manage_dashboard
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
      :spam_ticket,
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
      :manage_availability,
      :manage_canned_responses,
      :manage_dispatch_rules,
      :manage_supervisor_rules,
      :manage_scenario_automation_rules,
      :manage_email_settings,
      :admin_tasks,
      :export_tickets,
      :edit_private_note,
      :assign_agent,
      :assign_group,
      :import_customers,
      :export_customers,
      :manage_ticket_templates,
      :manage_skills,
      :edit_ticket_skill,
      :export_reports,
      :create_solution_draft,
      :manage_ticket_list_views,
      :compose_email,
      :manage_customer_list,
      :solution_view_reports,
      :solution_exports,
      :forums_view_reports,
      :forums_exports,
      :forums_admin_moderator,
      :solution_delete_versions,
      :solution_restore_versions,
      :solution_view_versions,
      :forum_advanced_moderator,
      :forum_basic_moderator,
      :manage_tags,
      :manage_bots,
      :manage_segments,
      :manage_proactive_outreaches,
      :untitled_core_supervisor_1,
      :untitled_core_supervisor_2,
      :untitled_core_supervisor_3,
      :untitled_core_supervisor_4,
      :untitled_core_supervisor_5,
      :untitled_core_supervisor_6,
      :create_tags,
      :view_bots,
      :untitled_core_agent_3,
      :untitled_core_agent_4,
      :untitled_core_agent_5,
      :untitled_solution_admin_1,
      :untitled_forums_admin_1,
      :untitled_solution_supervisor_1,
      :untitled_solution_supervisor_2,
      :untitled_forums_supervisor_1,
      :untitled_forums_supervisor_2,
      :untitled_solution_agent_1,
      :untitled_solution_agent_2,
      :untitled_solution_agent_3,
      :untitled_forum_agent_1,
      :untitled_forum_agent_2,
      :untitled_forum_agent_3,
      :view_social,                           #Social_privileges
      :social_convert_to_ticket,
      :social_reply_and_compose_post,
      :manage_social_response,
      :phone_attend_call,                     #FreshFone_privileges
      :phone_make_call,
      :phone_export_call_history,
      :livechat_admin_tasks,                  #LiveChat_privileges
      :livechat_manage_visitor,
      :livechat_view_transcripts,
      :livechat_edit_transcripts,
      :livechat_delete_transcripts,
      :livechat_accept_chat,
      :livechat_initiat_agent_chat,
      :livechat_view_visitors,
      :livechat_intiate_visitor_chat,
      :livechat_shadow_chat,
      :livechat_export_transcripts,
      :livechat_manage_shortcodes,
      :livechat_view_reports,
      :manage_calls,
      :manage_dashboard
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
      :spam_ticket,
      :view_solutions,
      :publish_solution,
      :delete_solution,
      :manage_solutions,
      :view_forums,
      :manage_forums,
      :view_admin,
      :manage_availability,
      :create_topic,
      :edit_topic,
      :delete_topic,
      :view_contacts,
      :manage_contacts,
      :delete_contact,
      :view_reports,
      :export_tickets,
      :edit_private_note,
      :assign_agent,
      :assign_group,
      :import_customers,
      :export_customers,
      :export_reports,
      :edit_ticket_skill,
      :create_solution_draft,
      :manage_ticket_list_views,
      :compose_email,
      :manage_customer_list,
      :solution_delete_versions,
      :solution_restore_versions,
      :solution_view_versions,
      :forum_advanced_moderator,
      :forum_basic_moderator,
      :untitled_core_supervisor_1,
      :untitled_core_supervisor_2,
      :untitled_core_supervisor_3,
      :untitled_core_supervisor_4,
      :untitled_core_supervisor_5,
      :untitled_core_supervisor_6,
      :create_tags,
      :view_bots,
      :untitled_core_agent_3,
      :untitled_core_agent_4,
      :untitled_core_agent_5,
      :untitled_solution_supervisor_1,
      :untitled_solution_supervisor_2,
      :untitled_forums_supervisor_1,
      :untitled_forums_supervisor_2,
      :untitled_solution_agent_1,
      :untitled_solution_agent_2,
      :untitled_solution_agent_3,
      :untitled_forum_agent_1,
      :untitled_forum_agent_2,
      :untitled_forum_agent_3,
      :view_social,                           #Social_privileges
      :social_convert_to_ticket,
      :social_reply_and_compose_post,
      :manage_social_response,
      :phone_attend_call,                     #FreshFone_privileges
      :phone_make_call,
      :phone_export_call_history,
      :livechat_manage_visitor,               #LiveChat_privileges
      :livechat_view_transcripts,
      :livechat_edit_transcripts,
      :livechat_delete_transcripts,
      :livechat_accept_chat,
      :livechat_initiat_agent_chat,
      :livechat_view_visitors,
      :livechat_intiate_visitor_chat,
      :livechat_shadow_chat,
      :livechat_export_transcripts,
      :livechat_manage_shortcodes,
      :livechat_view_reports,
      :manage_calls,
      :manage_dashboard
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
      :spam_ticket,
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
      :delete_contact,
      :edit_private_note,
      :assign_agent,
      :assign_group,
      :import_customers,
      :export_customers,
      :create_solution_draft,
      :compose_email,
      :solution_view_versions,
      :forum_basic_moderator,
      :create_tags,
      :view_bots,
      :untitled_core_agent_3,
      :untitled_core_agent_4,
      :untitled_core_agent_5,
      :untitled_solution_agent_1,
      :untitled_solution_agent_2,
      :untitled_solution_agent_3,
      :untitled_forum_agent_1,
      :untitled_forum_agent_2,
      :untitled_forum_agent_3,
      :view_social,                           #Social_privilege
      :phone_attend_call,                     #FreshFone_privileges
      :phone_make_call,
      :phone_export_call_history,
      :livechat_manage_visitor,               #LiveChat_privileges
      :livechat_view_transcripts,
      :livechat_edit_transcripts,
      :livechat_delete_transcripts,
      :livechat_accept_chat,
      :livechat_initiat_agent_chat,
      :livechat_view_visitors,
      :livechat_intiate_visitor_chat,
      :manage_calls
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
      :spam_ticket,
      :view_solutions,
      :publish_solution,
      :delete_solution,
      :manage_solutions,
      :view_forums,
      :create_topic,
      :edit_topic,
      :delete_topic,
      :edit_private_note,
      :assign_agent,
      :assign_group,
      :create_solution_draft,
      :compose_email,
      :view_social,                           #Social_privilege
      :phone_attend_call,                     #FreshFone_privileges
      :phone_make_call,
      :phone_export_call_history,
      :livechat_manage_visitor,               #LiveChat_privileges
      :livechat_view_transcripts,
      :livechat_edit_transcripts,
      :livechat_accept_chat,
      :livechat_initiat_agent_chat,
      :create_tags,
      :manage_calls
    ]

    DEFAULT_ROLES_LIST = 
    [  
      [ "Account Administrator",
        ACCOUNT_ADMINISTRATOR,
        "Has complete control over the help desk including access to Account or Billing related information, and receives Invoices.",
        :account_administrator],
      
      [ "Administrator",
        ADMINISTRATOR,
        "Can configure all features through the Admin tab, but is restricted from viewing Account or Billing related information.",
        :administrator],
      
      [ "Supervisor",
        SUPERVISOR,
        "Can perform all agent related activities, access reports and see unresolved tickets dashboard.",
        :supervisor],
      
      [ "Agent",
        AGENT,
        "Can log, view, reply, update and resolve tickets and manage contacts.",
        :agent],
     ]

    DEFAULT_ROLES_PRIVILEGE_BY_KEY = DEFAULT_ROLES_LIST.inject({}) {|hash,r| hash[r[3]] = r[1]; hash }
  end
end
