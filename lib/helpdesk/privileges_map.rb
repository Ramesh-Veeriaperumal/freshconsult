# frozen_string_literal: true

module Helpdesk
  module PrivilegesMap
    CHAT_PRIVILEGE_MAP = {
      manage_canned_responses: [:livechat_manage_shortcodes],
      manage_tickets: [:livechat_manage_visitor, :livechat_view_transcripts, :livechat_edit_transcripts,
                       :livechat_accept_chat, :livechat_initiat_agent_chat, :livechat_view_visitors,
                       :livechat_intiate_visitor_chat, :livechat_export_transcripts],
      delete_ticket: [:livechat_delete_transcripts],
      view_reports: [:livechat_view_reports],
      admin_tasks: [:livechat_admin_tasks, :livechat_shadow_chat]
    }.freeze

    FORUM_PRIVILEGES_MAP = {
      view_forums: [:forum_basic_moderator],
      manage_forums: [:forum_advanced_moderator, :forums_exports],
      admin_tasks: [:forums_admin_moderator],
      view_reports: [:forums_view_reports]
    }.freeze

    SOLUTION_PRIVILEGES_MAP = {
      view_solutions: [:create_solution_draft, :solution_view_versions],
      manage_solutions: [:solution_exports, :solution_delete_versions, :solution_restore_versions],
      view_reports: [:solution_view_reports]
    }.freeze

    CUSTOMER_PRIVILEGE_MAP = {
      manage_contacts: [:import_customers]
    }.freeze

    SOCIAL_PRIVILEGES_MAP = {
      manage_tickets: [:view_social, :social_convert_to_ticket],
      reply_ticket: [:social_reply_and_compose_post, :manage_social_response]
    }.freeze

    HELPDESK_PRIVILEGE_MAP = {
      edit_note: [:edit_private_note],
      edit_ticket_properties: [:assign_agent, :assign_group],
      manage_tickets: [:spam_ticket, :create_public_note, :service_task_assignee, :service_task_internal_assignee, :update_service_task_properties],
      manage_users: [:manage_collaborators, :provide_access_via_mentions]
    }.freeze

    ALL_PRIVILEGES = [HELPDESK_PRIVILEGE_MAP, SOCIAL_PRIVILEGES_MAP, CUSTOMER_PRIVILEGE_MAP,
                      SOLUTION_PRIVILEGES_MAP, FORUM_PRIVILEGES_MAP, CHAT_PRIVILEGE_MAP].freeze

    MIGRATION_MAP = ALL_PRIVILEGES.inject({}) do |hash, pr_map|
      hash.merge!(pr_map) { |key, oldval, newval| oldval | newval }
      hash
    end

    CONDITION_BASED_PRIVILEGES = {
      # Sample
      # delete_ticket: [ {privilege: [:spam_ticket], condition_key: :agent_type, condition_values: [1]}]
      manage_tickets: [
        { privilege: [:create_ticket], condition_key: :agent_type, condition_values: [1] },
        { privilege: [:execute_scenario_automation], condition_key: :agent_type, condition_values: [1] },
        { privilege: [:manage_parent_child_tickets], condition_key: :agent_type, condition_values: [1] },
        { privilege: [:manage_linked_tickets], condition_key: :agent_type, condition_values: [1] },
        { privilege: [:create_service_tasks], condition_key: :agent_type, condition_values: [1] },
        { privilege: [:delete_service_tasks], condition_key: :agent_type, condition_values: [1] },
        { privilege: [:ticket_assignee], condition_key: :agent_type, condition_values: [1] },
        { privilege: [:ticket_internal_assignee], condition_key: :agent_type, condition_values: [1] }
      ]
    }.freeze
  end
end



