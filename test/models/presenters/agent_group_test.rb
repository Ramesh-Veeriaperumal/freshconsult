require_relative '../test_helper'

class AgentGroupTest < ActiveSupport::TestCase
	include AgentGroupTestHelper

  def test_central_publish_payload
    agent_group = create_agent_group(@account)
    payload = agent_group.central_publish_payload.to_json
    msg = JSON.parse(payload)
    payload.must_match_json_expression(central_publish_agent_group_pattern(agent_group))
  end
end
