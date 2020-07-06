require_relative '../unit_test_helper'

class GroupFilterValidationTest < ActionView::TestCase

	def teardown
    super
    Account.unstub(:current)
  end

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end
  
  def test_group_type_valid
    group_filter = GroupFilterValidation.new(group_type: @account.group_types.first.name)
    assert group_filter.valid?
  end

  def test_group_type_invalid
    group_filter = GroupFilterValidation.new(group_type: nil)
    refute group_filter.valid?
  end

  def test_valid_channel_params_with_auto_assignment
    Account.any_instance.stubs(:omni_channel_routing_enabled?).returns(true)
    group_filter = GroupFilterValidation.new(include: 'omni_channel_groups', auto_assignment: 'true')
    assert group_filter.valid?
  ensure
    Account.any_instance.unstub(:omni_channel_routing_enabled?)
  end

  def test_valid_channel_params_without_auto_assignment
    Account.any_instance.stubs(:omni_channel_routing_enabled?).returns(true)
    group_filter = GroupFilterValidation.new(include: 'omni_channel_groups')
    assert group_filter.valid?
  ensure
    Account.any_instance.unstub(:omni_channel_routing_enabled?)
  end

  def test_invalid_channel_params_without_feature
    Account.any_instance.stubs(:omni_channel_routing_enabled?).returns(false)
    group_filter = GroupFilterValidation.new(include: 'omni_channel_groups', auto_assignment: 'true')
    refute group_filter.valid?
    error = group_filter.errors.full_messages
    assert error.include?('Include require_feature_for_attribute')
    assert error.include?('Auto assignment require_feature_for_attribute')
  ensure
    Account.any_instance.unstub(:omni_channel_routing_enabled?)
  end

  def test_invalid_channel_params_without_include
    Account.any_instance.stubs(:omni_channel_routing_enabled?).returns(true)
    group_filter = GroupFilterValidation.new(auto_assignment: 'true')
    refute group_filter.valid?
    error = group_filter.errors.full_messages
    assert error.include?('Auto assignment require_omni_channel_groups')
  ensure
    Account.any_instance.unstub(:omni_channel_routing_enabled?)
  end

  def test_invalid_include_param
    Account.any_instance.stubs(:omni_channel_routing_enabled?).returns(true)
    group_filter = GroupFilterValidation.new(include: 'omni_groups', auto_assignment: 'true')
    refute group_filter.valid?
    error = group_filter.errors.full_messages
    assert error.include?('Include not_included')
  ensure
    Account.any_instance.unstub(:omni_channel_routing_enabled?)
  end

  def test_invalid_auto_assignment_param
    Account.any_instance.stubs(:omni_channel_routing_enabled?).returns(true)
    group_filter = GroupFilterValidation.new(include: 'omni_channel_groups', auto_assignment: 'false')
    refute group_filter.valid?
    error = group_filter.errors.full_messages
    assert error.include?('Auto assignment not_included')
  ensure
    Account.any_instance.unstub(:omni_channel_routing_enabled?)
  end
end
