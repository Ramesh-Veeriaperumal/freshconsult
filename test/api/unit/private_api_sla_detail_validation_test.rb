require_relative '../unit_test_helper'

class PrivateApiSlaDetailsValidationTest < ActionView::TestCase
  def setup
    super
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(false)
  end

  def teardown
    Account.any_instance.unstub(:next_response_sla_enabled?)
    Account.unstub(:current)
  end

  def test_valid_sla_detail
    sla_validator = Ember::SlaDetailsValidation.new({ first_response_time: "PT15M", resolution_due_time: "PT2H", business_hours: true, escalation_enabled: true }, nil)
    assert sla_validator.valid?
  end

  def test_valid_sla_detail_with_next_response_sla_feature
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
    sla_validator = Ember::SlaDetailsValidation.new({ first_response_time: "PT15M", every_response_time: "PT1H", resolution_due_time: "PT2H", business_hours: true, escalation_enabled: true }, nil)
    assert sla_validator.valid?
  end

# ************************************************** Test first_response_time
  def test_first_response_time_nil
    sla_validator = Ember::SlaDetailsValidation.new({ first_response_time: nil, resolution_due_time: "PT2H", business_hours: true, escalation_enabled: true }, nil)
    refute sla_validator.valid?
    errors = sla_validator.errors.full_messages
    assert errors.include?('First response time blank')
  end

  def test_first_response_time_less_than_15_minutes
    sla_validator = Ember::SlaDetailsValidation.new({ first_response_time: "PT10M", resolution_due_time: "PT2H", business_hours: true, escalation_enabled: true }, nil)
    refute sla_validator.valid?
    errors = sla_validator.errors.full_messages
    assert errors.include?('First response time must_be_more_than_15_minutes')
  end

  def test_first_response_time_greater_than_1_year
    sla_validator = Ember::SlaDetailsValidation.new({ first_response_time: "P500D", resolution_due_time: "PT2H", business_hours: true, escalation_enabled: true }, nil)
    refute sla_validator.valid?
    errors = sla_validator.errors.full_messages
    assert errors.include?('First response time must_be_less_than_1_year')
  end

  def test_first_response_time_invalid_format
    sla_validator = Ember::SlaDetailsValidation.new({ first_response_time: "PT", resolution_due_time: "PT2H", business_hours: true, escalation_enabled: true }, nil)
    refute sla_validator.valid?
    errors = sla_validator.errors.full_messages
    assert errors.include?('First response time invalid_duration_format')
  end

  def test_first_response_time_invalid_data_type
    sla_validator = Ember::SlaDetailsValidation.new({ first_response_time: 900, resolution_due_time: "PT2H", business_hours: true, escalation_enabled: true }, nil)
    refute sla_validator.valid?
    errors = sla_validator.errors.full_messages
    assert errors.include?('First response time datatype_mismatch')
    assert_equal({ first_response_time: { expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer }, resolution_due_time: {}, business_hours: {}, escalation_enabled: {} }, sla_validator.error_options)
  end

  def test_without_first_response_time
    sla_validator = Ember::SlaDetailsValidation.new({ resolution_due_time: "PT2H", business_hours: true, escalation_enabled: true }, nil)
    refute sla_validator.valid?
    errors = sla_validator.errors.full_messages
    assert errors.include?('First response time missing_field')
    assert_equal({ first_response_time: { code: :missing_field }, resolution_due_time: {}, business_hours: {}, escalation_enabled: {} }, sla_validator.error_options)
  end

# ************************************************** Test every_response_time
  def test_every_response_time_less_than_15_minutes
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
    sla_validator = Ember::SlaDetailsValidation.new({ first_response_time: "PT15M", every_response_time: "PT10M", resolution_due_time: "PT2H", business_hours: true, escalation_enabled: true }, nil)
    refute sla_validator.valid?
    errors = sla_validator.errors.full_messages
    assert errors.include?('Every response time must_be_more_than_15_minutes')
  end

  def test_every_response_time_greater_than_1_year
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
    sla_validator = Ember::SlaDetailsValidation.new({ first_response_time: "PT15M", every_response_time: "P500D", resolution_due_time: "PT2H", business_hours: true, escalation_enabled: true }, nil)
    refute sla_validator.valid?
    errors = sla_validator.errors.full_messages
    assert errors.include?('Every response time must_be_less_than_1_year')
  end

  def test_every_response_time_invalid_format
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
    sla_validator = Ember::SlaDetailsValidation.new({ first_response_time: "PT15M", every_response_time: "PT", resolution_due_time: "PT2H", business_hours: true, escalation_enabled: true }, nil)
    refute sla_validator.valid?
    errors = sla_validator.errors.full_messages
    assert errors.include?('Every response time invalid_duration_format')
  end

  def test_every_response_time_invalid_data_type
    Account.any_instance.stubs(:next_response_sla_enabled?).returns(true)
    sla_validator = Ember::SlaDetailsValidation.new({ first_response_time: "PT15M", every_response_time: 900, resolution_due_time: "PT2H", business_hours: true, escalation_enabled: true }, nil)
    refute sla_validator.valid?
    errors = sla_validator.errors.full_messages
    assert errors.include?('Every response time datatype_mismatch')
    assert_equal({ first_response_time: {}, every_response_time: { expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer }, resolution_due_time: {}, business_hours: {}, escalation_enabled: {} }, sla_validator.error_options)
  end

# ************************************************** Test resolution_due_time
  def test_resolution_due_time_nil
    sla_validator = Ember::SlaDetailsValidation.new({ first_response_time: "PT15M", resolution_due_time: nil, business_hours: true, escalation_enabled: true }, nil)
    refute sla_validator.valid?
    errors = sla_validator.errors.full_messages
    assert errors.include?('Resolution due time blank')
  end

  def test_resolution_due_time_less_than_15_minutes
    sla_validator = Ember::SlaDetailsValidation.new({ first_response_time: "PT15M", resolution_due_time: "PT10M", business_hours: true, escalation_enabled: true }, nil)
    refute sla_validator.valid?
    errors = sla_validator.errors.full_messages
    assert errors.include?('Resolution due time must_be_more_than_15_minutes')
  end

  def test_resolution_due_time_greater_than_1_year
    sla_validator = Ember::SlaDetailsValidation.new({ first_response_time: "PT15M", resolution_due_time: "P500D", business_hours: true, escalation_enabled: true }, nil)
    refute sla_validator.valid?
    errors = sla_validator.errors.full_messages
    assert errors.include?('Resolution due time must_be_less_than_1_year')
  end

  def test_every_resolution_due_time_invalid_format
    sla_validator = Ember::SlaDetailsValidation.new({ first_response_time: "PT15M", resolution_due_time: "PT", business_hours: true, escalation_enabled: true }, nil)
    refute sla_validator.valid?
    errors = sla_validator.errors.full_messages
    assert errors.include?('Resolution due time invalid_duration_format')
  end

  def test_resolution_due_time_invalid_data_type
    sla_validator = Ember::SlaDetailsValidation.new({ first_response_time: "PT15M", resolution_due_time: 900, business_hours: true, escalation_enabled: true }, nil)
    refute sla_validator.valid?
    errors = sla_validator.errors.full_messages
    assert errors.include?('Resolution due time datatype_mismatch')
    assert_equal({ first_response_time: {}, resolution_due_time: { expected_data_type: String, prepend_msg: :input_received, given_data_type: Integer }, business_hours: {}, escalation_enabled: {} }, sla_validator.error_options)
  end

  def test_without_resolution_due_time
    sla_validator = Ember::SlaDetailsValidation.new({ first_response_time: "PT15M", business_hours: true, escalation_enabled: true }, nil)
    refute sla_validator.valid?
    errors = sla_validator.errors.full_messages
    assert errors.include?('Resolution due time missing_field')
    assert_equal({ first_response_time: {}, resolution_due_time: { code: :missing_field }, business_hours: {}, escalation_enabled: {} }, sla_validator.error_options)
  end
end
