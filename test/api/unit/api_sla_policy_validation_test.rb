require_relative '../unit_test_helper'

class ApiSlaPolicyValidationTest < ActionView::TestCase
  def test_value_valid
    sla = ApiSlaPolicyValidation.new({ applicable_to: { company_ids: [1, 2] } }, nil)
    assert sla.valid?
  end

  def test_value_missing
    sla = ApiSlaPolicyValidation.new({}, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Applicable to data_type_mismatch')
    assert_equal({ applicable_to: {  expected_data_type: 'key/value pair', code: :missing_field } }, sla.error_options)
  end

  def test_applicable_to_nil
    sla = ApiSlaPolicyValidation.new({ applicable_to: nil }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Applicable to data_type_mismatch')
  end

  def test_applicable_to_invalid_data_type
    sla = ApiSlaPolicyValidation.new({ applicable_to: [] }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Applicable to data_type_mismatch')
  end

  def test_company_ids_nil
    sla = ApiSlaPolicyValidation.new({ applicable_to: { company_ids: nil } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Company ids data_type_mismatch')
    assert_equal({ applicable_to: {}, company_ids: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'Null Type' } }, sla.error_options)
  end

  def test_company_ids_invalid_data_type
    sla = ApiSlaPolicyValidation.new({ applicable_to: { company_ids: {} } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Company ids data_type_mismatch')
    assert_equal({ applicable_to: {}, company_ids: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'key/value pair' } }, sla.error_options)
  end

  def test_company_ids_array_has_invalid_data_type
    sla = ApiSlaPolicyValidation.new({ applicable_to: { company_ids: ['123'] } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Company ids array_data_type_mismatch')
  end
end
