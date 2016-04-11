require_relative '../unit_test_helper'
require "#{Rails.root}/test/api/helpers/custom_field_validator_test_helper.rb"

class TicketValidationTest < ActionView::TestCase
  def tear_down
    Account.unstub(:current)
    super
  end

  def test_mandatory
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'requester_id' => 1, description: Faker::Lorem.paragraph,  ticket_fields: [] }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    assert ticket.valid?(:create)
    Account.unstub(:current)
  end

  def test_email_validation
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'email' => 'fggg,ss@fff.com',  ticket_fields: []  }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?
    errors = ticket.errors.full_messages
    assert errors.include?('Email invalid_format')
    assert_equal({ email: { accepted: :'valid email address' } }, ticket.error_options)
    Account.unstub(:current)
  end

  def test_cc_emails_validation
    Account.stubs(:current).returns(Account.first)
    controller_params = { ticket_fields: [], 'email' => 'fgggss@fff.com', 'cc_emails' => ['werewrwe@ddd.com, sdfsfdsf@ddd.com'] }
    item = nil,
           ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?
    errors = ticket.errors.full_messages
    assert errors.include?('Cc emails array_invalid_format')
    assert_equal({ email: {}, cc_emails: { accepted: :'valid email address' } }, ticket.error_options)
    Account.unstub(:current)
  end

  def test_tags_comma_invalid
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'requester_id' => 1, ticket_fields: [], tags: ['comma,test'] }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    errors = ticket.errors.full_messages
    assert errors.include?('Tags special_chars_present')
    assert_equal({ requester_id: {}, tags: { chars: ',' } }, ticket.error_options)
    Account.unstub(:current)
  end

  def test_tags_comma_valid
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'requester_id' => 1, description: Faker::Lorem.paragraph,  ticket_fields: [], tags: ['comma', 'test'] }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    assert ticket.valid?(:create)
    Account.unstub(:current)
  end

  def test_attachment_multiple_errors
    Account.stubs(:current).returns(Account.first)
    String.any_instance.stubs(:size).returns(20_000_000)
    TicketsValidationHelper.stubs(:attachment_size).returns(100)
    controller_params = { requester_id: 1, description: Faker::Lorem.paragraph, ticket_fields: [], attachments: ['file.png'] }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?
    errors = ticket.errors.full_messages
    assert errors.include?('Attachments array_datatype_mismatch')
    assert_equal({ requester_id: {}, description: {}, attachments: { expected_data_type: 'valid file format' } }, ticket.error_options)
    assert errors.count == 1
    Account.unstub(:current)
    TicketsValidationHelper.unstub(:attachment_size)
  end

  def test_tags_multiple_errors
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'requester_id' => 1, description: Faker::Lorem.paragraph,  ticket_fields: [], tags: 'comma,test' }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    errors = ticket.errors.full_messages
    assert errors.include?('Tags datatype_mismatch')
    assert_equal({ requester_id: {}, description: {}, tags: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: String } }, ticket.error_options)
    Account.unstub(:current)
  end

  def test_custom_fields_multiple_errors
    Account.stubs(:current).returns(Account.first)
    TicketsValidationHelper.stubs(:data_type_validatable_custom_fields).returns(CustomFieldValidatorTestHelper.data_type_validatable_custom_fields)
    controller_params = { 'requester_id' => 1, description: Faker::Lorem.paragraph,  ticket_fields: [], custom_fields: 'number1_1 = uioo' }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    errors = ticket.errors.full_messages
    assert errors.include?('Custom fields datatype_mismatch')
    assert_equal({ requester_id: {}, description: {}, custom_fields: { expected_data_type: 'key/value pair', prepend_msg: :input_received, given_data_type: String } }, ticket.error_options)
    TicketsValidationHelper.unstub(:data_type_validatable_custom_fields)
    Account.unstub(:current)
  end

  def test_fr_due_by_nil_and_due_by_nil_when_status_is_open
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'requester_id' => 1,  description: Faker::Lorem.paragraph,  ticket_fields: [], status_ids: [2, 3, 4, 5, 6], status: 2, due_by: nil, fr_due_by: nil }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    assert ticket.valid?(:create)
    Account.unstub(:current)
  end

  def test_fr_due_by_not_nil_and_due_by_not_nil_when_status_is_closed
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'requester_id' => 1,  description: Faker::Lorem.paragraph,  ticket_fields: [], status_ids: [2, 3, 4, 5, 6], status: 5, due_by: '', fr_due_by: '' }.with_indifferent_access
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    errors = ticket.errors.full_messages
    assert errors.include?('Due by cannot_set_due_by_fields')
    assert errors.include?('Fr due by cannot_set_due_by_fields')
    assert_equal({ status: {}, requester_id: {}, description: {}, fr_due_by: { code: :incompatible_field },
                   due_by: { code: :incompatible_field } }, ticket.error_options)
    Account.unstub(:current)
  end

  def test_status_priority_source_invalid
    Account.stubs(:current).returns(Account.first)
    controller_params = { status: true, priority: true, source: '3', status_ids: [2, 3, 4, 5, 6], ticket_fields: [] }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    errors = ticket.errors.full_messages
    assert errors.include?('Status not_included')
    assert errors.include?('Priority not_included')
    assert errors.include?('Source not_included')

    controller_params = { status: '2', priority: '2', source: '', status_ids: [2, 3, 4, 5, 6], ticket_fields: [] }
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    errors = ticket.errors.full_messages
    assert errors.include?('Status not_included')
    assert errors.include?('Priority not_included')
    assert errors.include?('Source not_included')
  ensure
    Account.unstub(:current)
  end

  def test_complex_fields_with_nil
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'requester_id' => 1, description: Faker::Lorem.paragraph,  ticket_fields: [], cc_emails: nil, tags: nil, custom_fields: nil, attachments: nil }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    errors = ticket.errors.full_messages
    assert errors.include?('Tags datatype_mismatch')
    assert errors.include?('Custom fields datatype_mismatch')
    assert errors.include?('Cc emails datatype_mismatch')
    assert errors.include?('Attachments blank')
    assert_equal({ requester_id: {}, description: {}, attachments: {}, cc_emails: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'Null'  },
                   tags: { expected_data_type: Array, prepend_msg: :input_received, given_data_type: 'Null'  },
                   custom_fields: { expected_data_type: 'key/value pair', prepend_msg: :input_received, given_data_type: 'Null'  } }, ticket.error_options)
    Account.unstub(:current)
  end

  def test_description
    Account.stubs(:current).returns(Account.first)
    desc_field = mock('desc_field')
    desc_field.stubs(:required).returns(true)
    desc_field.stubs(:default).returns(true)
    desc_field.stubs(:name).returns('description')
    controller_params = { 'requester_id' => 1, ticket_fields: [desc_field] }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    assert ticket.errors.full_messages.include?('Description datatype_mismatch')
    assert_equal({ description: {  expected_data_type: String, code: :missing_field }, requester_id: {} }, ticket.error_options)

    controller_params = { 'requester_id' => 1, ticket_fields: [desc_field], description: '' }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    assert ticket.errors.full_messages.include?('Description blank')
    assert_equal({ requester_id: {}, description: { expected_data_type: String } }, ticket.error_options)

    controller_params = { 'requester_id' => 1, ticket_fields: [desc_field], status_ids: [1, 2] }
    item = Helpdesk::Ticket.new
    item.description = ''
    item.description_html = 'test'
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:update)
    refute ticket.errors.full_messages.include?('Description blank')

    controller_params = { 'requester_id' => 1, ticket_fields: [desc_field], description: true }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    assert ticket.errors.full_messages.include?('Description datatype_mismatch')
    assert_equal({ requester_id: {}, description: { expected_data_type: String, prepend_msg: :input_received,
                                                    given_data_type: 'Boolean' } }, ticket.error_options)
    Account.unstub(:current)
  end

  def test_outbound_ticket_update
    Account.stubs(:current).returns(Account.first)
    Account.any_instance.stubs(:compose_email_enabled?).returns(true)
    controller_params = {  'subject' => Faker::Lorem.paragraph, 'description' => Faker::Lorem.paragraph,  ticket_fields: [], status_ids: [2, 3, 4, 5, 6] }
    item = Helpdesk::Ticket.new(requester_id: 1, status: 2, priority: 3, source: 10)
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:update)
    errors = ticket.errors.full_messages
    assert errors.include?('Subject outbound_email_field_restriction')
    assert errors.include?('Description outbound_email_field_restriction')
  ensure
    Account.any_instance.unstub(:compose_email_enabled?)
    Account.unstub(:current)
  end
end
