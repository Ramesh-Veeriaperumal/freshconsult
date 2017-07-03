require_relative '../unit_test_helper'

class TicketExportValidationTest < ActionView::TestCase
  def test_export_with_empty_params
    ticket_export_valdiation = TicketExportValidation.new({}, nil)
    refute ticket_export_valdiation.valid?
    errors = ticket_export_valdiation.errors.full_messages
    assert errors.include?('Format missing_field')
    assert errors.include?('Date filter missing_field')
    assert errors.include?('Ticket state filter missing_field')
    assert errors.include?('Query hash missing_field')

    Account.stubs(:current).returns(Account.new)
    controller_params = { format: 'csv', date_filter: '7', ticket_state_filter: 'resolved_at', query_hash: [{ 'condition' => 'created_at', 'operator' => 'is_greater_than', 'ff_name' => 'default', 'value' => '01 Jan 2017 - 15 Feb 2017' }], ticket_fields: [], contact_fields: [], company_fields: [] }
    ticket_export_valdiation = TicketExportValidation.new(controller_params, nil)
    refute ticket_export_valdiation.valid?
    errors = ticket_export_valdiation.errors.full_messages
    assert errors.include?('Request select_a_field')
    Account.unstub(:current)
  end

  def test_datatypes_for_export
    controller_params = { format: 1, date_filter: ['test'], ticket_state_filter: 3, start_date: ['test'], end_date: ['test'], query_hash: 'test', ticket_fields: 'test', contact_fields: 'test', company_fields: 'test' }
    ticket_export_valdiation = TicketExportValidation.new(controller_params, nil)
    refute ticket_export_valdiation.valid?
    errors = ticket_export_valdiation.errors.full_messages
    assert errors.include?('Format datatype_mismatch')
    assert errors.include?('Date filter datatype_mismatch')
    assert errors.include?('Ticket state filter datatype_mismatch')
    assert errors.include?('Start date invalid_date')
    assert errors.include?('End date invalid_date')
    assert errors.include?('Query hash datatype_mismatch')
    assert errors.include?('Ticket fields datatype_mismatch')
    assert errors.include?('Contact fields datatype_mismatch')
    assert errors.include?('Company fields datatype_mismatch')
  end

  def test_invalid_fields_for_export
    Account.stubs(:current).returns(Account.new)
    User.stubs(:current).returns(User.new)
    User.current.stubs(:privilege?).with(:export_customers).returns(false)
    controller_params = { format: 'csv', date_filter: '1', ticket_state_filter: '3', query_hash: [{ 'condition' => 'created_at', 'operator' => 'is_greater_than', 'ff_name' => 'default', 'value' => 'six_month' }], ticket_fields: ['test'], contact_fields: ['test'], company_fields: ['test'] }
    ticket_export_valdiation = TicketExportValidation.new(controller_params, nil)
    refute ticket_export_valdiation.valid?
    errors = ticket_export_valdiation.errors.full_messages
    assert errors.include?('Ticket state filter not_included')
    assert errors.include?('Ticket fields not_included')
    assert errors.include?('Contact fields not_included')
    assert errors.include?('Company fields not_included')
    User.current.unstub(:privilege?)
    User.unstub(:current)
    Account.unstub(:current)
  end

  def test_invalid_query_hash_for_export
    Account.stubs(:current).returns(Account.new)
    User.stubs(:current).returns(User.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    Account.any_instance.stubs(:company_form).returns(CompanyForm.new)
    ContactForm.any_instance.stubs(:contact_fields_from_cache).returns([contact_field('cf_location')])
    CompanyForm.any_instance.stubs(:company_fields_from_cache).returns([company_field('cf_address')])
    User.stubs(:current).returns(User.new)
    User.current.stubs(:privilege?).with(:export_customers).returns(true)
    controller_params = { format: 'csv', date_filter: '1', ticket_state_filter: 'created_at', query_hash: [{ 'condition' => 'status', 'operator' => 'is_n', 'type' => 'dummy', 'ff_name' => 'default' }, { 'condition' => 'responder_id', 'operaor' => 'is_in', 'ff_name' => 'default' }], ticket_fields: [], contact_fields: ['location'], company_fields: ['address'] }
    ticket_export_valdiation = TicketExportValidation.new(controller_params, nil)
    refute ticket_export_valdiation.valid?
    errors = ticket_export_valdiation.errors.full_messages
    assert errors.include?("Query hash[0] operator: It should be one of these values: 'is,is_in,is_greater_than,due_by_op' & type: It should be one of these values: 'default,custom_field' & value: Mandatory attribute missing")
    assert errors.include?("Query hash[1] operator: Mandatory attribute missing & value: Mandatory attribute missing")
    User.current.unstub(:privilege?)
    User.unstub(:current)
    Account.unstub(:current)
  end

  def test_validation_success
    Account.stubs(:current).returns(Account.new)
    Account.any_instance.stubs(:contact_form).returns(ContactForm.new)
    Account.any_instance.stubs(:company_form).returns(CompanyForm.new)
    ContactForm.any_instance.stubs(:contact_fields_from_cache).returns([contact_field('cf_location')])
    CompanyForm.any_instance.stubs(:company_fields_from_cache).returns([company_field('cf_address')])
    User.stubs(:current).returns(User.new)
    User.current.stubs(:privilege?).with(:export_customers).returns(true)
    controller_params = { format: 'csv', date_filter: '1', ticket_state_filter: 'created_at', query_hash: [{ 'condition' => 'created_at', 'operator' => 'is_greater_than', 'ff_name' => 'default', 'value' => 'six_month' }], ticket_fields: ['display_id'], contact_fields: ['location'], company_fields: ['address'] }
    ticket_export_valdiation = TicketExportValidation.new(controller_params, nil)
    assert ticket_export_valdiation.valid?
    User.current.unstub(:privilege?)
    User.unstub(:current)
    Account.unstub(:current)
  end

  def contact_field(name)
    contact_field = ContactField.new
    contact_field.name = name
    contact_field
  end

  def company_field(name)
    company_field = CompanyField.new
    company_field.name = name
    company_field
  end
end
