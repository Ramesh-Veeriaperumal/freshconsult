require_relative '../test_helper'

class FakeController < ApiApplicationController
  include TicketConcern
end

class FakeControllerTest < ActionController::TestCase
  def test_verify_ticket_permission_valid_without_params
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    @controller.instance_variable_set('@item', Helpdesk::Ticket.first)
    actual = @controller.send(:verify_ticket_permission)
    assert actual
  end

  def test_verify_ticket_permission_valid_with_params
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    ticket = Helpdesk::Ticket.new(requester_id: @agent.id, cc_email: { cc_emails: [], fwd_emails: [], reply_cc_emails: [] })
    ticket.save
    actual = @controller.send(:verify_ticket_permission, @agent, ticket)
    assert actual
  end

  def test_verify_ticket_permission_invalid_ticket
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    ticket = Helpdesk::Ticket.new(requester_id: @agent.id, cc_email: { cc_emails: [], fwd_emails: [], reply_cc_emails: [] })
    ticket.save
    ticket.schema_less_ticket.update_attribute(:trashed, true)
    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    @controller.send(:verify_ticket_permission, @agent, ticket)
    User.any_instance.unstub(:can_view_all_tickets)
    ticket.schema_less_ticket.update_attribute(:trashed, false)
    assert_equal 403, response.status
    assert_equal request_error_pattern(:access_denied).to_json, response.body
  end

  def test_verify_ticket_permission_invalid
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
    Helpdesk::Ticket.any_instance.stubs(:responder_id).returns(nil)
    Helpdesk::Ticket.any_instance.stubs(:requester_id).returns(nil)
    @controller.send(:verify_ticket_permission, @agent, Helpdesk::Ticket.first)
    User.any_instance.unstub(:can_view_all_tickets, :group_ticket_permission)
    Helpdesk::Ticket.any_instance.unstub(:responder_id, :requester_id)
    assert_equal 403, response.status
    assert_equal request_error_pattern(:access_denied).to_json, response.body
  end

  def test_verify_ticket_permission_has_ticket_permission_valid
    User.any_instance.stubs(:can_view_all_tickets?).returns(true).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
    Helpdesk::Ticket.any_instance.stubs(:responder_id).returns(nil)
    Helpdesk::Ticket.any_instance.stubs(:requester_id).returns(nil)
    actual = @controller.send(:verify_ticket_permission, @agent,  Helpdesk::Ticket.first)
    User.any_instance.unstub(:can_view_all_tickets, :group_ticket_permission)
    Helpdesk::Ticket.any_instance.unstub(:responder_id, :requester_id)
    assert actual
  end

  def test_verify_ticket_permission_with_group_ticket_permission_invalid
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(true).at_most_once
    Helpdesk::Ticket.any_instance.stubs(:responder_id).returns(nil)
    Helpdesk::Ticket.any_instance.stubs(:requester_id).returns(nil)
    User.any_instance.stubs(:agent_groups).returns([]).at_most_once
    @controller.send(:verify_ticket_permission, @agent,  Helpdesk::Ticket.first)
    User.any_instance.unstub(:can_view_all_tickets, :group_ticket_permission, :agent_groups)
    Helpdesk::Ticket.unstub(:responder_id, :requester_id)
    assert_equal 403, response.status
    assert_equal request_error_pattern(:access_denied).to_json, response.body
  end

  def test_verify_ticket_permission_with_responder_ticket_permission_valid
    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
    Helpdesk::Ticket.any_instance.stubs(:responder_id).returns(@agent.id)
    actual = @controller.send(:verify_ticket_permission, @agent,  Helpdesk::Ticket.first)
    User.any_instance.unstub(:can_view_all_tickets, :group_ticket_permission)
    Helpdesk::Ticket.unstub(:assigned_tickets_permission, :responder_id)
    assert actual
  end

  def test_verify_ticket_permission_with_requester_ticket_permission_valid
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
    Helpdesk::Ticket.any_instance.stubs(:requester_id).returns(@agent.id)
    actual = @controller.send(:verify_ticket_permission, @agent,  Helpdesk::Ticket.first)
    User.any_instance.unstub(:can_view_all_tickets, :group_ticket_permission)
    Helpdesk::Ticket.unstub(:assigned_tickets_permission, :requester_id)
    assert_equal 403, response.status
    assert_equal request_error_pattern(:access_denied).to_json, response.body
  end

  def test_verify_ticket_permission_with_group_ticket_permission_valid
    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(true).at_most_once
    Helpdesk::Ticket.any_instance.stubs(:responder_id).returns(nil)
    Helpdesk::Ticket.any_instance.stubs(:requester_id).returns(nil)
    group = Group.new(name: "#{Faker::Name.name}")
    group.agents = [@agent]
    group.save
    t = Helpdesk::Ticket.new(email: Faker::Internet.email, group_id: group.id)
    t.save
    actual = @controller.send(:verify_ticket_permission, @agent, t)
    Helpdesk::Ticket.unstub(:responder_id, :requester_id)
    User.any_instance.unstub(:can_view_all_tickets, :group_ticket_permission)
    assert actual
  end
end
