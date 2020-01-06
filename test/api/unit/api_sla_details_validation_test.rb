require_relative '../unit_test_helper'

class ApiSlaDetailsValidationTest < ActionView::TestCase
  def test_value_valid
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(false)
    sla = ApiSlaDetailsValidation.new({respond_within: 900, resolve_within: 7200, business_hours: true, escalation_enabled: true }, nil)
    assert sla.valid?
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_value_valid_with_next_response_feature
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
    sla = ApiSlaDetailsValidation.new({respond_within: 900, next_respond_within: 900, resolve_within: 7200, business_hours: true, escalation_enabled: true }, nil)
    assert sla.valid?
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  # ******************************************** respond_within
  def test_respond_within_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(false)
    sla = ApiSlaDetailsValidation.new({respond_within: nil, resolve_within: 7200, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Respond within blank')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_respond_within_below_900
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(false)
    sla = ApiSlaDetailsValidation.new({respond_within: 400, resolve_within: 7200, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Respond within must be greater than or equal to 900')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_respond_within_Not_multiple_60
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(false)
    sla = ApiSlaDetailsValidation.new({respond_within: 6789, resolve_within: 7200, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Respond within Multiple_of_60')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_respond_within_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(false)
    sla = ApiSlaDetailsValidation.new({respond_within: "test", resolve_within: 7200, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Respond within datatype_mismatch')
    assert_equal({ respond_within: { expected_data_type: :Integer, prepend_msg: :input_received, given_data_type: String, code: :datatype_mismatch}, resolve_within: {}, business_hours: {}, escalation_enabled: {} }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_without_respond_within
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(false)
    sla = ApiSlaDetailsValidation.new({ resolve_within: 7200, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Respond within missing_field')
    assert_equal({ respond_within: { code: :missing_field }, resolve_within: {}, business_hours: {}, escalation_enabled: {} }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  # ******************************************** next_respond_within
  def test_next_respond_within_below_900
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
    sla = ApiSlaDetailsValidation.new({respond_within: 900, next_respond_within: 400, resolve_within: 7200, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Next respond within must be greater than or equal to 900')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_next_respond_within_not_multiple_60
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
    sla = ApiSlaDetailsValidation.new({respond_within: 900, next_respond_within: 6789, resolve_within: 7200, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Next respond within Multiple_of_60')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_next_respond_within_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
    sla = ApiSlaDetailsValidation.new({respond_within: 900, next_respond_within: "test", resolve_within: 7200, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Next respond within datatype_mismatch')
    assert_equal({ respond_within: {}, next_respond_within: { expected_data_type: :Integer, prepend_msg: :input_received, given_data_type: String, code: :datatype_mismatch}, resolve_within: {}, business_hours: {}, escalation_enabled: {} }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_without_next_respond_within
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
    sla = ApiSlaDetailsValidation.new({ respond_within: 900, resolve_within: 7200, business_hours: true, escalation_enabled: true }, nil)
    assert sla.valid?
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  # ******************************************** resolve_within

  def test_resolve_within_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(false)
    sla = ApiSlaDetailsValidation.new({respond_within: 7200, resolve_within: nil, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Resolve within blank')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_resolve_within_below_900
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(false)
    sla = ApiSlaDetailsValidation.new({respond_within: 900, resolve_within: 200, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Resolve within must be greater than or equal to 900')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_resolve_within_Not_multiple_60
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(false)
    sla = ApiSlaDetailsValidation.new({respond_within: 6000, resolve_within: 7201, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Resolve within Multiple_of_60')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_resolve_within_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(false)
    sla = ApiSlaDetailsValidation.new({respond_within: 7200, resolve_within: "Test", business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Resolve within datatype_mismatch')
    assert_equal({ respond_within: {}, resolve_within: { expected_data_type: :Integer, prepend_msg: :input_received, given_data_type: String, code: :datatype_mismatch}, business_hours: {}, escalation_enabled: {} }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_without_resolve_within
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(false)
    sla = ApiSlaDetailsValidation.new({ respond_within: 7200, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Resolve within missing_field')
    assert_equal({ respond_within: {}, resolve_within:  { code: :missing_field }, business_hours: {}, escalation_enabled: {} }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end
  # ******************************************** Business hour and Escalation enabled
  
  def test_business_hours_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(false)
    sla = ApiSlaDetailsValidation.new({ respond_within: 1800, resolve_within: 7200, business_hours: nil, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Business hours blank')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_business_hours_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(false)
    sla = ApiSlaDetailsValidation.new({ respond_within: 1800, resolve_within: 7200, business_hours: "true", escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Business hours datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_without_business_hours
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(false)
    sla = ApiSlaDetailsValidation.new({ respond_within: 1800, resolve_within: 7200, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Business hours missing_field')
    assert_equal({ respond_within: {}, resolve_within: {}, business_hours: { code: :missing_field },  escalation_enabled: {} }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_escalation_enableds_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(false)
    sla = ApiSlaDetailsValidation.new({ respond_within: 1800, resolve_within: 7200, business_hours: true, escalation_enabled: nil }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Escalation enabled blank')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_escalation_enabled_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(false)
    sla = ApiSlaDetailsValidation.new({ respond_within: 1800, resolve_within: 7200, business_hours: true, escalation_enabled: "true" }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Escalation enabled datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

  def test_without_escalation_enabled
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(false)
    sla = ApiSlaDetailsValidation.new({ respond_within: 1800, resolve_within: 7200, business_hours: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Escalation enabled missing_field')
    assert_equal({ respond_within: {}, resolve_within: {}, business_hours: {}, escalation_enabled: { code: :missing_field } }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:next_response_sla_enabled?)
  end

end