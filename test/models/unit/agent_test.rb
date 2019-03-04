require_relative '../test_helper'

class AgentTest < ActiveSupport::TestCase
  include AgentTestHelper

  def test_agent_availability_sync_to_ocr
    Account.current.add_feature(:omni_channel_routing)
    OmniChannelRouting::AgentSync.jobs.clear
    update_agent_availability
    assert_equal 1, OmniChannelRouting::AgentSync.jobs.size
  ensure
    Account.current.revoke_feature(:omni_channel_routing)
  end
end
