[ 'agents_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
module ProfilesTestHelper
  include AgentsTestHelper

  def profile_pattern(user)
    agent = user.agent
    private_api_agent_pattern(agent).merge!(additional_agent_info(agent))
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
