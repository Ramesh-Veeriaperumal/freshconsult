require_relative '../unit_test_helper'

class AgentValidationTest < ActionView::TestCase
  def teardown
    Account.unstub(:current)
    super
  end

  def test_valid_agent_export
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:skill_based_round_robin_enabled?).returns(false)
    agent_export = AgentExportValidation.new(response_type: 'api', fields: ['email', 'name', 'phone'])
    assert agent_export.valid?
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:skill_based_round_robin_enabled?)
  end

  def test_export_invalid_values
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:skill_based_round_robin_enabled?).returns(false)
    agent_export = AgentExportValidation.new(response_type: 'call', fields: ['email', 'name', 'phone', 'emp_id'])
    refute agent_export.valid?(:export)
    errors = agent_export.errors.sort.to_h
    error_options = agent_export.error_options.sort.to_h
    assert_equal({ fields: :invalid_values, response_type: :not_included }, errors)
    assert_equal({ fields: { fields: 'emp_id' }, response_type: { list: 'email,api' } }, error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:skill_based_round_robin_enabled?)
  end

  def test_export_invalid_datatypes
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:skill_based_round_robin_enabled?).returns(false)
    agent_export = AgentExportValidation.new(response_type: 123, fields: 'name')
    refute agent_export.valid?(:export)
    errors = agent_export.errors.sort.to_h
    error_options = agent_export.error_options.sort.to_h
    assert_equal({ fields: :datatype_mismatch, response_type: :not_included }, errors)
    assert_equal({ fields: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: String }, response_type: { list: 'email,api' } }, error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:skill_based_round_robin_enabled?)
  end

  def test_export_with_skills_in_fields
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:skill_based_round_robin_enabled?).returns(false)
    agent_export = AgentExportValidation.new(response_type: 'call', fields: ['email', 'name', 'phone', 'skills'])
    refute agent_export.valid?(:export)
    errors = agent_export.errors.sort.to_h
    error_options = agent_export.error_options.sort.to_h
    assert_equal({ fields: :invalid_values, response_type: :not_included }, errors)
    assert_equal({ fields: { fields: 'skills' }, response_type: { list: 'email,api' } }, error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:skill_based_round_robin_enabled?)
  end
end
