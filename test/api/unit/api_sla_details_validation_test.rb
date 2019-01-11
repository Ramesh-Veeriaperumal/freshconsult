require_relative '../unit_test_helper'

class ApiSlaDetailsValidationTest < ActionView::TestCase
  def test_value_valid
    sla = ApiSlaDetailsValidation.new({respond_within: 900, resolve_within: 7200, business_hours: true, escalation_enabled: true }, nil)
    assert sla.valid?
  end

  # ******************************************************************************** respond_within
  def test_respond_within_nil
    sla = ApiSlaDetailsValidation.new({respond_within: nil, resolve_within: 7200, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Respond within blank')
  end

  def test_respond_within_below_900
    sla = ApiSlaDetailsValidation.new({respond_within: 400, resolve_within: 7200, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Respond within must be greater than or equal to 900')
  end

  def test_respond_within_Not_multiple_60
    sla = ApiSlaDetailsValidation.new({respond_within: 6789, resolve_within: 7200, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Respond within Multiple_of_60')
  end

  def test_respond_within_invalid_data_type
    sla = ApiSlaDetailsValidation.new({respond_within: "test", resolve_within: 7200, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Respond within datatype_mismatch')
    assert_equal({ respond_within: { expected_data_type: :Integer, prepend_msg: :input_received, given_data_type: String, code: :datatype_mismatch}, resolve_within: {}, business_hours: {}, escalation_enabled: {} }, sla.error_options)
  end

  def test_without_respond_within
    sla = ApiSlaDetailsValidation.new({ resolve_within: 7200, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Respond within missing_field')
    assert_equal({ respond_within: { code: :missing_field }, resolve_within: {}, business_hours: {}, escalation_enabled: {} }, sla.error_options)
  end

  # ******************************************************************************** resolve_within

  def test_resolve_within_nil
    sla = ApiSlaDetailsValidation.new({respond_within: 7200, resolve_within: nil, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Resolve within blank')
  end

  def test_resolve_within_below_900
    sla = ApiSlaDetailsValidation.new({respond_within: 900, resolve_within: 200, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Resolve within must be greater than or equal to 900')
  end

  def test_resolve_within_Not_multiple_60
    sla = ApiSlaDetailsValidation.new({respond_within: 6000, resolve_within: 7201, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Resolve within Multiple_of_60')
  end

  def test_resolve_within_invalid_data_type
    sla = ApiSlaDetailsValidation.new({respond_within: 7200, resolve_within: "Test", business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Resolve within datatype_mismatch')
    assert_equal({ respond_within: {}, resolve_within: { expected_data_type: :Integer, prepend_msg: :input_received, given_data_type: String, code: :datatype_mismatch}, business_hours: {}, escalation_enabled: {} }, sla.error_options)
  end

  def test_without_resolve_within
    sla = ApiSlaDetailsValidation.new({ respond_within: 7200, business_hours: true, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Resolve within missing_field')
    assert_equal({ respond_within: {}, resolve_within:  { code: :missing_field }, business_hours: {}, escalation_enabled: {} }, sla.error_options)
  end
  # ******************************************************************************** Business hour and Escalation enabled
  
  def test_business_hours_nil
    sla = ApiSlaDetailsValidation.new({ respond_within: 1800, resolve_within: 7200, business_hours: nil, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Business hours blank')
  end

  def test_business_hours_invalid_data_type
    sla = ApiSlaDetailsValidation.new({ respond_within: 1800, resolve_within: 7200, business_hours: "true", escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Business hours datatype_mismatch')
  end

  def test_without_business_hours
    sla = ApiSlaDetailsValidation.new({ respond_within: 1800, resolve_within: 7200, escalation_enabled: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Business hours missing_field')
    assert_equal({ respond_within: {}, resolve_within: {}, business_hours: { code: :missing_field },  escalation_enabled: {} }, sla.error_options)
  end

  def test_escalation_enableds_nil
    sla = ApiSlaDetailsValidation.new({ respond_within: 1800, resolve_within: 7200, business_hours: true, escalation_enabled: nil }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Escalation enabled blank')
  end

  def test_escalation_enabled_invalid_data_type
    sla = ApiSlaDetailsValidation.new({ respond_within: 1800, resolve_within: 7200, business_hours: true, escalation_enabled: "true" }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Escalation enabled datatype_mismatch')
  end

  def test_without_escalation_enabled
    sla = ApiSlaDetailsValidation.new({ respond_within: 1800, resolve_within: 7200, business_hours: true }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Escalation enabled missing_field')
    assert_equal({ respond_within: {}, resolve_within: {}, business_hours: {}, escalation_enabled: { code: :missing_field } }, sla.error_options)
  end

end