require_relative '../unit_test_helper'

class TicketBulkUpdateValidationTest < ActionView::TestCase
  
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

  def test_update_with_invalid_params
    User.stubs(:current).returns(User.first)
    controller_params = { ids: [1, 2, 3], ticket_fields: [], statuses: statuses }
    ticket_validation = TicketBulkUpdateValidation.new(controller_params)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Request select_a_field')

    controller_params = { ids: [1, 2, 3], properties: {}, reply: {}, ticket_fields: [], statuses: statuses }
    ticket_validation = TicketBulkUpdateValidation.new(controller_params)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Request select_a_field')
    User.unstub(:current)
  end

  def test_property_update
    User.stubs(:current).returns(User.first)
    controller_params = { ids: [1, 2, 3], properties: { priority: 100 }, ticket_fields: [], statuses: statuses }
    ticket_validation = TicketBulkUpdateValidation.new(controller_params)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Priority not_included')  

    controller_params = { ids: [1, 2, 3], properties: { priority: 2 }, ticket_fields: [], statuses: statuses }
    ticket_validation = TicketBulkUpdateValidation.new(controller_params)
    assert ticket_validation.valid?
    User.unstub(:current)
  end

  def test_reply
    User.stubs(:current).returns(User.first)
    controller_params = { ids: [1, 2, 3], reply: { body: Faker::Lorem.paragraph, from_email: Faker::Lorem.word } }
    ticket_validation = TicketBulkUpdateValidation.new(controller_params)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('From email invalid_format')  

    controller_params = { ids: [1, 2, 3], reply: { body: Faker::Lorem.paragraph, from_email: Faker::Internet.email } }
    ticket_validation = TicketBulkUpdateValidation.new(controller_params)
    assert ticket_validation.valid?
    User.unstub(:current)
  end

  def test_reply_without_privilege
    User.stubs(:current).returns(User.first)
    User.any_instance.stubs(:privilege?).with(:reply_ticket).returns(false)
    controller_params = { ids: [1, 2, 3], reply: { body: Faker::Lorem.paragraph } }.with_indifferent_access
    ticket_validation = TicketBulkUpdateValidation.new(controller_params)
    refute ticket_validation.valid?
    errors = ticket_validation.errors.full_messages
    assert errors.include?('Reply no_reply_privilege')  
    User.any_instance.unstub(:privilege?)
    User.unstub(:current)
  end

  def test_property_update_and_reply
    User.stubs(:current).returns(User.first)
    controller_params = { ids: [1, 2, 3], properties: { status: 4 }, reply: { body: Faker::Lorem.paragraph }, ticket_fields: [], statuses: statuses }
    ticket_validation = TicketBulkUpdateValidation.new(controller_params)
    assert ticket_validation.valid?
    User.unstub(:current)
  end
end
