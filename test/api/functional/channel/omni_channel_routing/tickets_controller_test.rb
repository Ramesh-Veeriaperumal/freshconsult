require_relative '../../../test_helper'
class Channel::OmniChannelRouting::TicketsControllerTest < ActionController::TestCase
  include OcrHelper

  def test_tickets_assign
    append_header
    sample_ticket = Helpdesk::Ticket.first
    group_id = sample_ticket.group_id
    ticket_id = sample_ticket.display_id
    ActionController::Parameters.any_instance.stubs(:permit).returns(true)
    put :assign, construct_params(version: 'channel/ocr', id: ticket_id, agent_id: 1, current_state: { group_id: group_id })
    assert_response 200
  end

  def test_tickets_assign_no_responder
    append_header
    sample_ticket = Helpdesk::Ticket.first
    group_id = sample_ticket.group_id
    ticket_id = sample_ticket.display_id
    ticket_responder_id = sample_ticket.responder_id
    sample_ticket.responder_id = nil
    sample_ticket.save
    Helpdesk::Ticket.any_instance.stubs(:responder_id).returns(nil)
    put :assign, construct_params(version: 'channel/ocr', id: ticket_id, agent_id: 4343424343, current_state: { group_id: group_id })
    sample_ticket.responder_id = ticket_responder_id
    sample_ticket.save
    assert_response 400
  end

  def test_tickets_assign_not_found
    append_header
    sample_ticket = Helpdesk::Ticket.first
    group_id = sample_ticket.group_id
    ticket_id = sample_ticket.display_id
    ActionController::Parameters.any_instance.stubs(:permit).returns(true)
    put :assign, construct_params(version: 'channel/ocr', id: 0, agent_id: 1, current_state: { group_id: group_id })
    assert_response 404
  end
end
