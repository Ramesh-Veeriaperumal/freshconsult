# frozen_string_literal: true

module Agents::CollaboratorHelper
  def collaborator?(agent_type)
    collaborator_type_id = AgentType.agent_type_id(Agent::COLLABORATOR)
    agent_type == collaborator_type_id
  end
end
