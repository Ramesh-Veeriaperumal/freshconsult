require_relative '../unit_test_helper'

class TicketValidationTest < ActionView::TestCase
  def tear_down
    Account.unstub(:current)
    super
  end

  def test_mandatory
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'requester_id' => 1, ticket_fields: [] }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    assert ticket.valid?(:create)
    Account.unstub(:current)
  end

  def test_email_validation
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'email' => 'fggg,ss@fff.com', ticket_fields: []  }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?
    errors = ticket.errors.full_messages
    assert errors.include?('Email not_a_valid_email')
    Account.unstub(:current)
  end

  def test_cc_emails_validation
    Account.stubs(:current).returns(Account.first)
    controller_params = { ticket_fields: [], 'email' => 'fgggss@fff.com', 'cc_emails' => ['werewrwe@ddd.com, sdfsfdsf@ddd.com'] }
    item = nil,
           ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?
    errors = ticket.errors.full_messages
    assert errors.include?('Cc emails not_a_valid_email')
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
    Account.unstub(:current)
  end

  def test_tags_comma_valid
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'requester_id' => 1, ticket_fields: [], tags: ['comma', 'test'] }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    assert ticket.valid?(:create)
    Account.unstub(:current)
  end

  def test_attachment_multiple_errors
    Account.stubs(:current).returns(Account.first)
    String.any_instance.stubs(:size).returns(20_000_000)
    Helpers::TicketsValidationHelper.stubs(:attachment_size).returns(100)
    controller_params = { requester_id: 1, ticket_fields: [], attachments: ['file.png'] }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?
    errors = ticket.errors.full_messages
    assert errors.include?('Attachments data_type_mismatch')
    assert errors.count == 1
    Account.unstub(:current)
    Helpers::TicketsValidationHelper.unstub(:attachment_size)
  end

  def test_tags_multiple_errors
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'requester_id' => 1, ticket_fields: [], tags: 'comma,test' }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    errors = ticket.errors.full_messages
    assert errors.include?('Tags data_type_mismatch')
    Account.unstub(:current)
  end

  def test_custom_fields_multiple_errors
    Account.stubs(:current).returns(Account.first)
    Helpers::TicketsValidationHelper.stubs(:data_type_validatable_custom_fields).returns(Helpers::CustomFieldValidatorHelper.data_type_validatable_custom_fields)
    controller_params = { 'requester_id' => 1, ticket_fields: [], custom_fields: 'number1_1 = uioo' }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    errors = ticket.errors.full_messages
    assert errors.include?('Custom fields data_type_mismatch')
    Helpers::TicketsValidationHelper.unstub(:data_type_validatable_custom_fields)
    Account.unstub(:current)
  end

  def test_fr_due_by_nil_and_due_by_nil_when_status_is_closed
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'requester_id' => 1, ticket_fields: [], status_ids: [2, 3, 4, 5, 6], status: 5, due_by: nil, fr_due_by: nil }
    item = nil
    ticket = TicketValidation.new(controller_params, item)
    assert ticket.valid?(:create)
    Account.unstub(:current)
  end

end
