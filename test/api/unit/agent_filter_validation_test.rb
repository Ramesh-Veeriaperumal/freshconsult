require_relative '../unit_test_helper'

class AgentFilterValidationTest < ActionView::TestCase
  def test_valid
    agent_filter = AgentFilterValidation.new(state: 'fulltime', phone: Faker::PhoneNumber.phone_number,
                                             mobile: Faker::PhoneNumber.phone_number, email: Faker::Internet.email)
    assert agent_filter.valid?
  end

  def test_nil
    agent_filter = AgentFilterValidation.new(state: nil, phone: nil, mobile: nil, email: nil)
    refute agent_filter.valid?
    error = agent_filter.errors.full_messages
    assert error.include?('State not_included')
    assert error.include?('Phone data_type_mismatch')
    assert error.include?('Mobile data_type_mismatch')
    assert error.include?('Email data_type_mismatch')
  end
end
