require_relative '../unit_test_helper'

class ApiSlaPolicyValidationTest < ActionView::TestCase
  def test_value_valid
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { company_ids: [1, 2] } }, nil)
    assert sla.valid?
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end
  
  def test_name_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ name: nil }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Name datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_name_nil_for_create
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { company_ids: [1, 2] } }, nil)
    refute sla.valid?(:create)
    errors = sla.errors.full_messages
    
    assert errors.include?('Name missing_field')
    assert errors.include?('Sla target missing_field')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end
  
  def test_name_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ name: nil }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Name datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_name_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ name: [] }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Name datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_name_invalid_data_type_create
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ name: [] }, nil)
    refute sla.valid?(:create)
    errors = sla.errors.full_messages
    assert errors.include?('Name blank')
    assert errors.include?('Applicable to missing_field')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_description_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ description: nil }, nil)
    assert sla.valid? 
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_description_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ description: [] }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Description datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_active_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ active: nil }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Active datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_active_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ active: [] }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Active datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  # ************************************************************************************ applicable to

  def test_applicable_to_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: nil }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Applicable to datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_applicable_to_nil_create
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: nil }, nil)
    refute sla.valid?(:create)
    errors = sla.errors.full_messages
    assert errors.include?('Applicable to blank')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_applicable_to_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: [] }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Applicable to datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  # ************************************************************************************ company_ids
  def test_company_ids_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { company_ids: nil } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Company ids datatype_mismatch')
    assert_equal({ applicable_to: {}, company_ids: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'Null'  } }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_company_ids_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { company_ids: {} } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Company ids datatype_mismatch')
    assert_equal({ applicable_to: {}, company_ids: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'key/value pair' } }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_company_ids_array_has_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { company_ids: ['123'] } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Company ids array_datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  # ************************************************************************************ contact_segments
  def test_contact_segments_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(true)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { contact_segments: nil } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Contact segments datatype_mismatch')
    assert_equal({ applicable_to: {}, contact_segments: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'Null'  } }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_contact_segments_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(true)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { contact_segments: {} } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Contact segments datatype_mismatch')
    assert_equal({ applicable_to: {}, contact_segments: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'key/value pair' } }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_contact_segments_array_has_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(true)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { contact_segments: ['123'] } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Contact segments array_datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  # ************************************************************************************ company_segments
  def test_company_segments_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(true)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { company_segments: nil } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Company segments datatype_mismatch')
    assert_equal({ applicable_to: {}, company_segments: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'Null'  } }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_company_segments_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(true)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { company_segments: {} } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Company segments datatype_mismatch')
    assert_equal({ applicable_to: {}, company_segments: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'key/value pair' } }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_company_segments_array_has_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(true)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { company_segments: ['123'] } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Company segments array_datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  # ************************************************************************************ product_ids
  def test_product_ids_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { product_ids: nil } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Product ids datatype_mismatch')
    assert_equal({ applicable_to: {}, product_ids: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'Null'  } }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_product_ids_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { product_ids: {} } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Product ids datatype_mismatch')
    assert_equal({ applicable_to: {}, product_ids: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'key/value pair' } }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_product_ids_array_has_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { product_ids: ['123'] } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Product ids array_datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  # ************************************************************************************ group_ids
  def test_group_ids_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { group_ids: nil } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Group ids datatype_mismatch')
    assert_equal({ applicable_to: {}, group_ids: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'Null'  } }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_group_ids_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { group_ids: {} } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Group ids datatype_mismatch')
    assert_equal({ applicable_to: {}, group_ids: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'key/value pair' } }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_group_ids_array_has_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { group_ids: ['123'] } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Group ids array_datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  # ************************************************************************************ ticket_types
  def test_ticket_types_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { ticket_types: nil } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Ticket types datatype_mismatch')
    assert_equal({ applicable_to: {}, ticket_types: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'Null'  } }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_ticket_types_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { ticket_types: {} } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Ticket types datatype_mismatch')
    assert_equal({ applicable_to: {}, ticket_types: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'key/value pair' } }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_ticket_types_array_has_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { ticket_types: [123] } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Ticket types array_datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  # ************************************************************************************ sources
  def test_sources_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { sources: nil } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Sources datatype_mismatch')
    assert_equal({ applicable_to: {}, sources: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'Null'  } }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_sources_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { sources: {} } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Sources datatype_mismatch')
    assert_equal({ applicable_to: {}, sources: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'key/value pair' } }, sla.error_options)
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_sources_array_has_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ applicable_to: { sources: ['123'] } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Sources array_datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  # ************************************************************************************ Sla targets
  def test_sla_target_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ sla_target: nil }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Sla target datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_sla_target_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ sla_target: [] }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Sla target datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  # ************************************************************************************ escalation
  def test_escalation_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ escalation: nil }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Escalation datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_escalation_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ escalation: [] }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Escalation datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end
  
  # ************************************************************************************ response
  def test_response_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ escalation: { response: nil } }, nil)
    assert sla.valid?
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_response_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ escalation: { response: [] } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Response datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  # ************************************************************************************ resolution
  def test_resolution_nil
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new({ escalation: { resolution: nil } }, nil)
    assert sla.valid?
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

  def test_resolution_invalid_data_type
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:segments_enabled?).returns(false)
    sla = ApiSlaPolicyValidation.new( { escalation: { resolution: [] } }, nil)
    refute sla.valid?
    errors = sla.errors.full_messages
    assert errors.include?('Resolution datatype_mismatch')
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:segments_enabled?)
  end

end
