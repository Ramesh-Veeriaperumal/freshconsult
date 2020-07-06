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
    Agent.any_instance.stubs(:perform_shift_request).returns(code: 200, body: { 'data' => [] })
    agent = Agent.first
    assert_nothing_raised do
      assert_equal nil, agent.out_of_office
    end
  ensure
    Account.current.rollback :out_of_office
    Agent.any_instance.unstub(:perform_shift_request)
  end

  def test_out_office_should_return_true_for_wrong_response
    Account.current.launch :out_of_office
    user = User.first.make_current
    Agent.any_instance.stubs(:perform_shift_request).returns(code: 200, body: { 'data' => ['test'] })
    agent = Agent.first
    assert_equal true, agent.out_of_office
  ensure
    Account.current.rollback :out_of_office
    Agent.any_instance.unstub(:perform_shift_request)
  end

  def test_toggle_availability_without_round_robin_and_agent_statuses
    Account.current.revoke_feature :round_robin
    Account.current.rollback :agent_statuses
    agent = Agent.first
    assert_equal false, agent.toggle_availability?
  end

  def test_toggle_availability_with_round_robin_without_agent_statuses
    Account.current.add_feature :round_robin
    agent = User.first
    group = Group.new(name: Faker::Name.name, ticket_assign_type: 1, toggle_availability: true)
    group.agents = [agent]
    group.save
    assert_equal true, agent.toggle_availability?
  ensure
    Account.current.revoke_feature :round_robin
  end
end
