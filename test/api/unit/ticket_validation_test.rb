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
end
