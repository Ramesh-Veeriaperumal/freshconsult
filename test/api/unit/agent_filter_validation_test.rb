require_relative '../unit_test_helper'

class AgentFilterValidationTest < ActionView::TestCase
  def teardown
    super
    Account.unstub(:current)
  end

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def test_valid
    agent_filter = AgentFilterValidation.new(state: 'fulltime', phone: Faker::PhoneNumber.phone_number,
                                             mobile: Faker::PhoneNumber.phone_number, email: Faker::Internet.email,
                                             only: 'available')
    assert agent_filter.valid?
  end

  def test_nil
    agent_filter = AgentFilterValidation.new(state: nil, phone: nil, mobile: nil, email: nil)
    refute agent_filter.valid?
    error = agent_filter.errors.full_messages
    assert error.include?('State not_included')
    assert error.include?('Phone datatype_mismatch')
    assert error.include?('Mobile datatype_mismatch')
    assert error.include?('Email datatype_mismatch')
  end

  def test_valid_omniroute_params
    Account.current.stubs(:omni_channel_routing_enabled?).returns(true)
    Account.current.stubs(:agent_statuses_enabled?).returns(true)
    agent_filter = AgentFilterValidation.new(only: 'availability', channel: 'freshdesk', group_id: '2222', search_term: 'change', available_in: 'chat')
    assert agent_filter.valid?
  ensure
    Account.current.unstub(:omni_channel_routing_enabled?)
    Account.current.unstub(:agent_statuses_enabled?)
  end

  def test_valid_channel_param
    Account.current.stubs(:omni_channel_routing_enabled?).returns(true)
    Account.current.stubs(:agent_statuses_enabled?).returns(true)
    agent_filter = AgentFilterValidation.new(only: 'availability', channel: 'random', group_id: '2222', search_term: 'change')
    refute agent_filter.valid?
    error = agent_filter.errors.full_messages
    assert error.include?('Channel not_included')
  ensure
    Account.current.unstub(:omni_channel_routing_enabled?)
    Account.current.unstub(:agent_statuses_enabled?)
  end

  def test_channel_with_group_id
    Account.current.stubs(:omni_channel_routing_enabled?).returns(true)
    Account.current.stubs(:agent_statuses_enabled?).returns(true)
    agent_filter = AgentFilterValidation.new(only: 'availability', channel: 'freshdesk')
    refute agent_filter.valid?
    error = agent_filter.errors.full_messages
    assert error.include?('Channel require_group_id')
  ensure
    Account.current.unstub(:omni_channel_routing_enabled?)
    Account.current.unstub(:agent_statuses_enabled?)
  end

  def test_group_id_with_channel
    Account.current.stubs(:omni_channel_routing_enabled?).returns(true)
    Account.current.stubs(:agent_statuses_enabled?).returns(false)
    Account.current.stubs(:omni_agent_availability_dashboard_enabled?).returns(true)
    agent_filter = AgentFilterValidation.new(only: 'availability', group_id: '2222')
    refute agent_filter.valid?
    error = agent_filter.errors.full_messages
    assert error.include?('Group require_channel')
  ensure
    Account.current.unstub(:omni_channel_routing_enabled?)
    Account.current.unstub(:agent_statuses_enabled?)
    Account.current.unstub(:omni_agent_availability_dashboard_enabled?)
  end

  def test_group_as_string_with_availability
    Account.current.stubs(:omni_channel_routing_enabled?).returns(true)
    Account.current.stubs(:agent_statuses_enabled?).returns(true)
    agent_filter = AgentFilterValidation.new(only: 'availability', channel: 'freshdesk', group_id: 2222)
    refute agent_filter.valid?
    error = agent_filter.errors.full_messages
    assert error.include?('Group datatype_mismatch')
  ensure
    Account.current.unstub(:omni_channel_routing_enabled?)
    Account.current.unstub(:agent_statuses_enabled?)
  end

  def test_valid_available_in_param
    Account.current.stubs(:omni_channel_routing_enabled?).returns(true)
    Account.current.stubs(:agent_statuses_enabled?).returns(true)
    agent_filter = AgentFilterValidation.new(only: 'availability', available_in: 'value')
    refute agent_filter.valid?
    error = agent_filter.errors.full_messages
    assert error.include?('Available in not_included')
  ensure
    Account.current.unstub(:omni_channel_routing_enabled?)
    Account.current.unstub(:agent_statuses_enabled?)
  end
end
