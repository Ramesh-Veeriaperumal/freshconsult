require_relative '../unit_test_helper'
require "#{Rails.root}/test/api/helpers/custom_field_validator_test_helper.rb"

class TicketUpdatePropertyValidationTest < ActionView::TestCase
  
  def statuses
    statuses  = []
    (2...7).map do |x|
      h = Helpdesk::TicketStatus.new
      h.status_id = x
      h.stop_sla_timer = true if [3, 4, 5, 6].include?(x)
      statuses << h
    end
    statuses
  end

  def test_property_update_with_no_params
    Account.stubs(:current).returns(Account.first)
    item = Helpdesk::Ticket.new(requester_id: 1, status: 2, priority: 3, source: 10)
    ticket_validation = TicketUpdatePropertyValidation.new({}, item)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Request fill_a_mandatory_field')
    Account.unstub(:current)
  end

  def test_due_by_validation
    Account.stubs(:current).returns(Account.first)
    item = Helpdesk::Ticket.new(requester_id: 1, status: 2, priority: 3, source: 10, frDueBy: nil)
    controller_params = { 'due_by' => 10, statuses: statuses, ticket_fields: [] }
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Fr due by fr_due_by_validation')

    item.frDueBy = 5.days.from_now
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Due by invalid_date')

    controller_params = { 'due_by' => 2.days.from_now.utc.iso8601, statuses: statuses, ticket_fields: [] }
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Due by lt_due_by')

    controller_params = { 'due_by' => nil, statuses: statuses, ticket_fields: [] }
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Due by due_by_validation')

    controller_params = { due_by: 10.days.from_now.utc.iso8601, statuses: statuses, ticket_fields: [] }.with_indifferent_access
    item.status = 5
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Due by cannot_set_due_by_fields')
    Account.unstub(:current)
  end

  def test_status_validation
    Account.stubs(:current).returns(Account.first)
    item = Helpdesk::Ticket.new(requester_id: 1, status: 2, priority: 3, source: 10)
    controller_params = { 'status' => 10, statuses: statuses, ticket_fields: [] }
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Status not_included')
    Account.unstub(:current)
  end

  def test_numericality
    Account.stubs(:current).returns(Account.first)
    item = Helpdesk::Ticket.new(requester_id: 1, status: 2, priority: 3, source: 10)
    controller_params = { 'responder_id' => 'Test', priority: 'Test', statuses: statuses, ticket_fields: [] }
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Agent datatype_mismatch')
    assert errors.include?('Priority not_included')

    controller_params = { 'group_id' => 'Test', statuses: statuses, ticket_fields: [] }
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Group datatype_mismatch')
    Account.unstub(:current)
  end

  def test_custom_fields_validation
    Account.stubs(:current).returns(Account.first)
    custom_fields = CustomFieldValidatorTestHelper.required_closure_data_type_validatable_custom_fields.first(10)
    TicketsValidationHelper.stubs(:data_type_validatable_custom_fields).returns(custom_fields)
    item = Helpdesk::Ticket.new(requester_id: 1, status: 2, priority: 3, source: 10)
    controller_params = { status: 4, statuses: statuses, ticket_fields: custom_fields }
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    custom_fields.each do |x|
      assert errors.include?("#{x.name.capitalize.gsub('_', ' ')} datatype_mismatch")
    end
    TicketsValidationHelper.unstub(:data_type_validatable_custom_fields)
    Account.unstub(:current)
  end

  def test_default_fields_required_validation
    Account.stubs(:current).returns(Account.first)
    agent_field = mock('agent')
    agent_field.stubs(:required).returns(true)
    agent_field.stubs(:default).returns(true)
    agent_field.stubs(:name).returns('agent')
    agent_field.stubs(:label).returns('Agent')
    item = Helpdesk::Ticket.new(requester_id: 1, status: 2, priority: 3, source: 10)
    controller_params = { 'responder_id' => nil, statuses: statuses, ticket_fields: [agent_field] }
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Agent datatype_mismatch')
    Account.unstub(:current)
  end

  def test_default_fields_required_for_closure_validation
    Account.stubs(:current).returns(Account.first)
    agent_field = mock('agent')
    agent_field.stubs(:required).returns(false)
    agent_field.stubs(:required_for_closure).returns(true)
    agent_field.stubs(:default).returns(true)
    agent_field.stubs(:name).returns('agent')
    agent_field.stubs(:label).returns('Agent')
    item = Helpdesk::Ticket.new(requester_id: 1, status: 2, priority: 3, source: 10)
    controller_params = { status: 4, statuses: statuses, ticket_fields: [agent_field] }
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Agent datatype_mismatch')
    Account.unstub(:current)
  end

  def test_validation_success
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'group_id' => 10, 'responder_id' => 10, status: 3, priority: 2, statuses: statuses, ticket_fields: []}
    item = Helpdesk::Ticket.new(requester_id: 1, status: 2, priority: 3, source: 10)
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    assert ticket_validation.valid?
    Account.unstub(:current)
  end
end
