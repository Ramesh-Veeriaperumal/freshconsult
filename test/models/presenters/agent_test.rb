require_relative '../test_helper'

class AgentTest < ActiveSupport::TestCase
  include AgentTestHelper

  def test_agent_update_without_feature
    @account.rollback(:audit_logs_central_publish)
    CentralPublishWorker::UserWorker.jobs.clear
    update_agent
    assert_equal 0, CentralPublishWorker::UserWorker.jobs.size
  ensure
    @account.launch(:audit_logs_central_publish)
  end

  def test_agent_update_with_feature
    CentralPublishWorker::UserWorker.jobs.clear
    update_agent
    assert_equal 1, CentralPublishWorker::UserWorker.jobs.size
    agent = Account.current.agents.first
    payload = agent.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_post_pattern(agent))
  end
end
