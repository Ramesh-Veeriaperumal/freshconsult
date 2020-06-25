require_relative '../test_helper'

class AgentTest < ActiveSupport::TestCase
  include AgentTestHelper
  require 'webmock/minitest'
  WebMock.allow_net_connect!

  def test_agent_availability_sync_to_ocr
    Account.current.add_feature(:omni_channel_routing)
    OmniChannelRouting::AgentSync.jobs.clear
    update_agent_availability
    assert_equal 1, OmniChannelRouting::AgentSync.jobs.size
  ensure
    Account.current.revoke_feature(:omni_channel_routing)
  end

  def test_out_office_should_return_nil_for_emtpy_response
    Account.current.launch :out_of_office
    user = User.first.make_current
    req_stub = stub_request(:get, %r{^http://localhost:8080/api/v1/out-of-offices.*?$}).to_return(status: 200, body: {}.to_json)
    agent = Agent.first
    agent.out_of_office
    assert_equal agent.out_of_office, nil
  ensure
    Account.current.rollback :out_of_office
  end
end
