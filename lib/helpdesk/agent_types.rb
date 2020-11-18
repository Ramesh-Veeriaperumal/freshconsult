# frozen_string_literal: true

module Helpdesk
  module AgentTypes
    PRIVILEGES = YAML.load_file(Rails.root.join('config', 'privileges.yml'))

    SUPPORT_AGENT_PRIVILEGES = PRIVILEGES[:privileges].keys

    FIELD_AGENT_PRIVILEGES = [
      :manage_tickets,
      :publish_solution,
      :create_and_edit_article,
      :edit_conversation,
      :forward_ticket,
      :edit_time_entries,
      :edit_ticket_properties,
      :manage_solutions,
      :reply_ticket,
      :view_time_entries,
      :view_solutions,
      :delete_solution,
      :export_tickets,
      :assign_agent,
      :assign_group,
      :create_solution_draft,
      :create_tags,
      :solution_exports,
      :view_contacts,
      :manage_contacts,
      :manage_segments,
      :edit_note,
      :view_secure_field,
      :edit_secure_field,
      :delete_ticket,
      :publish_approved_solution,
      :approve_article,
      :export_articles,
      :manage_solution_templates,
      :manage_freddy_answers,
      :view_forums,
      :manage_forums,
      :create_topic,
      :edit_topic,
      :delete_topic,
      :delete_contact,
      :export_customers,
      :schedule_fsm_dashboard,
      :view_field_tech_location,
      :access_to_map_view,
      :view_reports,
      :export_reports,
      :manage_dashboard,
      :view_analytics,
      :manage_tags,
      :manage_canned_responses,
      :manage_ticket_list_views,
      :manage_bots,
      :manage_custom_objects,
      :create_public_note,
      :spam_ticket,
      :manage_linked_tickets,
      :manage_chats,
      :service_task_assignee,
      :service_task_internal_assignee,
      :create_service_tasks,
      :update_service_tasks,
      :delete_service_tasks
    ].freeze

    AGENT_TYPE_PRIVILEGE_MAPPING = {
      Agent::SUPPORT_AGENT.to_sym => SUPPORT_AGENT_PRIVILEGES,
      Agent::FIELD_AGENT.to_sym => FIELD_AGENT_PRIVILEGES
    }.freeze

    SUPPORT_AGENT_ID = AgentType.agent_type_id(Agent::SUPPORT_AGENT.to_sym)
    FIELD_AGENT_ID = AgentType.agent_type_id(Agent::FIELD_AGENT.to_sym)

    AGENT_TYPE_ID_PRIVILEGE_MAPPING = {
      SUPPORT_AGENT_ID => SUPPORT_AGENT_PRIVILEGES,
      FIELD_AGENT_ID => FIELD_AGENT_PRIVILEGES
    }.freeze
  end
end
