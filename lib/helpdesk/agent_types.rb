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
      :manage_segments
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
