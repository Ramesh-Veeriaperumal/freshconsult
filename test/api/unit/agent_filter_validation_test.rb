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
    agent_filter = AgentFilterValidation.new(only: 'availability', channel: 'freshdesk', group_id: '2222', search_term: 'change')
    assert agent_filter.valid?
  end

  def test_valid_channel_param
    agent_filter = AgentFilterValidation.new(only: 'availability', channel: 'random', group_id: '2222', search_term: 'change')
    refute agent_filter.valid?
    error = agent_filter.errors.full_messages
    assert error.include?('Channel not_included')
  end

  def test_channel_with_group_id
    agent_filter = AgentFilterValidation.new(only: 'availability', channel: 'freshdesk')
    refute agent_filter.valid?
    error = agent_filter.errors.full_messages
    assert error.include?('Channel require_group_id')
  end

  def test_group_id_with_channel
    agent_filter = AgentFilterValidation.new(only: 'availability', group_id: '2222')
    refute agent_filter.valid?
    error = agent_filter.errors.full_messages
    assert error.include?('Group require_channel')
  end

  def test_group_as_string_with_availability
    agent_filter = AgentFilterValidation.new(only: 'availability', channel: 'freshdesk', group_id: 2222)
    refute agent_filter.valid?
    error = agent_filter.errors.full_messages
    assert error.include?('Group datatype_mismatch')
  end
end
