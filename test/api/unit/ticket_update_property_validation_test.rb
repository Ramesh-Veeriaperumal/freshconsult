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
    ticket_validation = TicketUpdatePropertyValidation.new({ticket_fields: []}, item)
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
    status_field = mock('status')
    status_field.stubs(:required).returns(false)
    status_field.stubs(:required_for_closure).returns(false)
    status_field.stubs(:default).returns(true)
    status_field.stubs(:name).returns('status')
    status_field.stubs(:label).returns('Status')
    item = Helpdesk::Ticket.new(requester_id: 1, status: 2, priority: 3, source: 10)
    controller_params = { status: 10, statuses: statuses, ticket_fields: [status_field] }
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Status not_included')
    Account.unstub(:current)
  end

  def test_numericality
    Account.stubs(:current).returns(Account.first)
    item = Helpdesk::Ticket.new(requester_id: 1, status: 2, priority: 3, source: 10)
    agent_field = mock('agent')
    agent_field.stubs(:required).returns(false)
    agent_field.stubs(:required_for_closure).returns(false)
    agent_field.stubs(:default).returns(true)
    agent_field.stubs(:name).returns('agent')
    agent_field.stubs(:label).returns('Agent')
    priority_field = mock('priority')
    priority_field.stubs(:required).returns(false)
    priority_field.stubs(:required_for_closure).returns(false)
    priority_field.stubs(:default).returns(true)
    priority_field.stubs(:name).returns('priority')
    priority_field.stubs(:label).returns('Priority')
    controller_params = { responder_id: 'Test', priority: 'Test', statuses: statuses, ticket_fields: [agent_field, priority_field] }
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Agent datatype_mismatch')
    assert errors.include?('Priority not_included')

    group_field = mock('group')
    group_field.stubs(:required).returns(false)
    group_field.stubs(:required_for_closure).returns(false)
    group_field.stubs(:default).returns(true)
    group_field.stubs(:name).returns('group')
    group_field.stubs(:label).returns('Group')
    controller_params = { group_id: 'Test', statuses: statuses, ticket_fields: [group_field] }
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Group datatype_mismatch')
    Account.unstub(:current)
  end


  def test_tags_comma_invalid
    Account.stubs(:current).returns(Account.first)
    controller_params = { statuses: statuses, ticket_fields: [], tags: ['tag1,tag2'] }
    item = Helpdesk::Ticket.new(requester_id: 1, status: 2, priority: 3, source: 10)
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Tags special_chars_present')
    Account.unstub(:current)
  end

  def test_tags_comma_valid
    Account.stubs(:current).returns(Account.first)
    controller_params = { statuses: statuses, ticket_fields: [], tags: ['tag1','tag2'] }
    item = Helpdesk::Ticket.new(requester_id: 1, status: 2, priority: 3, source: 10)
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    assert ticket_validation.valid?
    Account.unstub(:current)
  end

  def test_tags_multiple_errors
    Account.stubs(:current).returns(Account.first)
    controller_params = { statuses: statuses, ticket_fields: [], tags: 'tag1,tag2' }
    item = Helpdesk::Ticket.new(requester_id: 1, status: 2, priority: 3, source: 10)
    ticket = TicketUpdatePropertyValidation.new(controller_params, item)
    refute ticket.valid?(:create)
    errors = ticket.errors.full_messages
    assert errors.include?('Tags datatype_mismatch')
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
    agent_field.stubs(:required_for_closure).returns(false)
    agent_field.stubs(:default).returns(true)
    agent_field.stubs(:name).returns('agent')
    agent_field.stubs(:label).returns('Agent')
    item = Helpdesk::Ticket.new(requester_id: 1, status: 2, priority: 3, source: 10)
    controller_params = { responder_id: nil, statuses: statuses, ticket_fields: [agent_field] }
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Agent datatype_mismatch')

    controller_params = { priority: 4, statuses: statuses, ticket_fields: [agent_field] }
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    assert ticket_validation.valid?
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

  def test_skip_notification_validation
    Account.stubs(:current).returns(Account.first)
    item = Helpdesk::Ticket.new(requester_id: 1, status: 2, priority: 3, source: 10)
    controller_params = { status: 3, statuses: statuses, ticket_fields: [], 'skip_close_notification' => true }
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Skip close notification cannot_set_skip_notification')

    controller_params = { status: 5, statuses: statuses, ticket_fields: [], 'skip_close_notification' => true }
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    assert ticket_validation.valid?
    Account.unstub(:current)
  end

  def test_validation_success
    Account.stubs(:current).returns(Account.first)
    controller_params = { 'group_id' => 10, 'responder_id' => 10, status: 3, priority: 2, statuses: statuses, ticket_fields: [], tags: ["tag1", "tag2"]}
    item = Helpdesk::Ticket.new(requester_id: 1, status: 2, priority: 3, source: 10)
    ticket_validation = TicketUpdatePropertyValidation.new(controller_params, item)
    assert ticket_validation.valid?
    Account.unstub(:current)
  end
end
