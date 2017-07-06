require_relative '../unit_test_helper'

class DashboardValidationTest < ActionView::TestCase
  # valid
  def test_group_ids
    Account.stubs(:current).returns(Account.first)
    contoller_params = { group_ids: [59] }
    dashboard = DashboardValidation.new(contoller_params)
    assert dashboard.valid?
  end

  def test_product_ids
    Account.stubs(:current).returns(Account.first)
    contoller_params = { product_ids: [1] }
    dashboard = DashboardValidation.new(contoller_params)
    assert dashboard.valid?
    Account.unstub(:current)
  end

  def test_status_ids
    Account.stubs(:current).returns(Account.first)
    contoller_params = { status_ids: [2] }
    dashboard = DashboardValidation.new(contoller_params)
    assert dashboard.valid?
    Account.unstub(:current)
  end

  def test_group_by
    Account.stubs(:current).returns(Account.first)
    contoller_params = { group_by: 'group_id' }
    dashboard = DashboardValidation.new(contoller_params)
    assert dashboard.valid?(:unresolved_tickets_data)
    Account.unstub(:current)
  end

  def test_responder_ids
    Account.stubs(:current).returns(Account.first)
    contoller_params = { responder_ids: [7] }
    dashboard = DashboardValidation.new(contoller_params)
    assert dashboard.valid?
    Account.unstub(:current)
  end

  # invalid
  def test_group_ids_invalid
    Account.stubs(:current).returns(Account.first)
    contoller_params = { group_ids: 59 }
    dashboard = DashboardValidation.new(contoller_params)
    refute dashboard.valid?
    errors = dashboard.errors.full_messages
    assert errors.include?('Group ids datatype_mismatch')
    assert_equal({ group_ids: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: Integer } }, dashboard.error_options)
    Account.unstub(:current)
  end

  def test_product_ids_invalid
    Account.stubs(:current).returns(Account.first)
    contoller_params = { product_ids: 1 }
    dashboard = DashboardValidation.new(contoller_params)
    refute dashboard.valid?
    errors = dashboard.errors.full_messages
    assert errors.include?('Product ids datatype_mismatch')
    assert_equal({ product_ids: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: Integer } }, dashboard.error_options)
    Account.unstub(:current)
  end

  def test_status_ids_invalid
    Account.stubs(:current).returns(Account.first)
    contoller_params = { status_ids: 2 }
    dashboard = DashboardValidation.new(contoller_params)
    refute dashboard.valid?
    errors = dashboard.errors.full_messages
    assert errors.include?('Status ids datatype_mismatch')
    assert_equal({ status_ids: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: Integer } }, dashboard.error_options)
    Account.unstub(:current)
  end

  def test_group_by_invalid
    Account.stubs(:current).returns(Account.first)
    contoller_params = { group_by: 'status_id' }
    dashboard = DashboardValidation.new(contoller_params)
    refute dashboard.valid?(:unresolved_tickets_data)
    Account.unstub(:current)
  end

  def test_group_by_mandatory
    Account.stubs(:current).returns(Account.first)
    contoller_params = {}
    dashboard = DashboardValidation.new(contoller_params)
    refute dashboard.valid?(:unresolved_tickets_data)
    errors = dashboard.errors.full_messages
    assert errors.include?('Group by missing_field')
    Account.unstub(:current)
  end

  def test_responder_ids_invalid
    Account.stubs(:current).returns(Account.first)
    contoller_params = { responder_ids: 7 }
    dashboard = DashboardValidation.new(contoller_params)
    refute dashboard.valid?
    errors = dashboard.errors.full_messages
    assert errors.include?('Responder ids datatype_mismatch')
    assert_equal({ responder_ids: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: Integer } }, dashboard.error_options)
    Account.unstub(:current)
  end
end
