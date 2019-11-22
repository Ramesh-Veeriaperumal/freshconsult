[ 'agents_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

module ProfilesTestHelper
  include AgentsTestHelper

  def profile_pattern(user)
    agent = user.agent
    private_api_profile_pattern(agent).merge!(additional_agent_info(agent))
  end


  def private_api_profile_pattern(expected_output = {}, agent)
    {

        available: expected_output[:available] || agent.available,
        occasional: expected_output[:occasional] || agent.occasional,
        id: Fixnum,
        ticket_scope: expected_output[:ticket_scope] || agent.ticket_permission,
        signature: expected_output[:signature_html] || agent.signature_html,
        role_ids: expected_output[:role_ids] || agent.user.role_ids,
        group_ids: expected_output[:group_ids] || agent.group_ids,
        skill_ids: expected_output[:skill_ids] || agent.user.skill_ids,
        available_since: expected_output[:available_since] || agent.active_since,
        contact: contact_pattern(expected_output[:user] || agent.user),
        created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
        updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
        type: Account.current.agent_types_from_cache.find { |type| type.agent_type_id == agent.agent_type }.name
    }
  end

  def additional_agent_info(agent)
    {
      last_active_at:   agent.last_active_at.try(:utc).try(:iso8601),
      assumable_agents: agent.assumable_agents.map(&:id),
      preferences:      agent.preferences,
      api_key:          agent.user.single_access_token
    }
  end
end
