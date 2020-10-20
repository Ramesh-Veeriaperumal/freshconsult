require_relative '../test_helper'

class FakeController < ApiApplicationController
  include TicketConcern
end

class FakeControllerTest < ActionController::TestCase
  include TicketFieldsTestHelper

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
    User.any_instance.stubs(:associated_group_ids).returns([]).at_most_once
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

  def test_verify_ticket_permission_with_internal_agent_ticket_permission_valid
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    group = Group.new(name: "#{Faker::Name.name}")
    group.agents = [@agent]
    group.save
    status = create_custom_status

    t = Helpdesk::Ticket.new(email: Faker::Internet.email, :status => status.status_id)
    t.save
    t.update_column(:internal_group_id, group.id)
    t.update_column(:internal_agent_id, @agent.id)
    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)

    status.group_ids = [group.id]
    status.save

    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
    actual = @controller.send(:verify_ticket_permission, @agent, t)
    User.any_instance.unstub(:can_view_all_tickets, :group_ticket_permission)
    Helpdesk::Ticket.unstub(:assigned_tickets_permission, :responder_id)
    Account.any_instance.unstub(:features?)
    assert actual
  ensure
    status.destroy
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
    User.any_instance.stubs(:can_view_all_tickets?).returns(false)
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

  def test_verify_ticket_permission_with_internal_group_ticket_permission_valid
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    group = Group.new(name: "#{Faker::Name.name}")
    group.agents = [@agent]
    group.save
    status = create_custom_status

    t = Helpdesk::Ticket.new(email: Faker::Internet.email, :status => status.status_id)
    t.save
    t.update_column(:internal_group_id, group.id)

    Account.any_instance.stubs(:shared_ownership_enabled?).returns(true)

    status.group_ids = [group.id]
    status.save
    User.any_instance.stubs(:can_view_all_tickets?).returns(false)
    User.any_instance.stubs(:group_ticket_permission).returns(true)
    Helpdesk::Ticket.any_instance.stubs(:responder_id).returns(nil)
    Helpdesk::Ticket.any_instance.stubs(:requester_id).returns(nil)
    actual = @controller.send(:verify_ticket_permission, @agent, t)
    Helpdesk::Ticket.unstub(:responder_id, :requester_id)
    User.any_instance.unstub(:can_view_all_tickets, :group_ticket_permission)
    Account.any_instance.unstub(:features?)
    assert actual
  ensure
    status.destroy
  end

  def test_verify_ticket_permission_for_freshcaller_ticket
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
    ticket = Helpdesk::Ticket.first
    ticket.source = Helpdesk::Source::PHONE
    ticket.save!
    ticket.reload
    old_meta = ticket.notes.find_by_source(Account.current.helpdesk_sources.note_source_keys_by_token['meta'])
    old_meta.destroy if old_meta.present?
    meta_data = {
      freshcaller: true,
      created_by: @agent.id,
      time: Time.now + 2.minutes
    }
    meta_note = ticket.notes.build(
          note_body_attributes: { body: meta_data.map { |k, v| "#{k}: #{v}" }.join("\n") },
          private: true,
          notable: ticket,
          user: ticket.requester,
          source: Account.current.helpdesk_sources.note_source_keys_by_token['meta'],
          account_id: ticket.account.id,
          user_id: ticket.requester.id,
          disable_observer: true
        )
    meta_note.save
    freshcaller_call = Freshcaller::Call.new(fc_call_id: Faker::Number.number(2), notable_id: ticket.id, notable_type: 'Helpdesk::Ticket')
    freshcaller_call.save!
    ticket.freshcaller_call = freshcaller_call
    ticket.save!
    actual = @controller.send(:verify_ticket_permission, @agent,  ticket)
    assert actual
  ensure
    User.any_instance.unstub(:can_view_all_tickets, :group_ticket_permission)
    ticket.freshcaller_call.destroy
    ticket.notes.find_by_source(Account.current.helpdesk_sources.note_source_keys_by_token["meta"]).destroy
  end

  def test_verify_ticket_permission_for_invalid_freshcaller_agent
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
    ticket = Helpdesk::Ticket.first
    old_meta = ticket.notes.find_by_source(Account.current.helpdesk_sources.note_source_keys_by_token['meta'])
    old_meta.destroy if old_meta.present?
    meta_data = {
      created_by: Faker::Number.number(5),
      freshcaller: true,
      time: Time.now + 2.minutes
    }
    meta_note = ticket.notes.build(
                  note_body_attributes: { body: meta_data.map { |k, v| "#{k}: #{v}" }.join("\n") },
                  private: true,
                  notable: ticket,
                  user: ticket.requester,
                  source: Account.current.helpdesk_sources.note_source_keys_by_token['meta'],
                  account_id: ticket.account.id,
                  user_id: ticket.requester.id,
                  disable_observer: true
                )
    meta_note.save
    freshcaller_call = Freshcaller::Call.new(fc_call_id: Faker::Number.number(2), notable_id: ticket.id, notable_type: 'Helpdesk::Ticket')
    freshcaller_call.save!
    @controller.send(:verify_ticket_permission, @agent, ticket)
    assert_equal 403, response.status
  ensure
    User.any_instance.unstub(:can_view_all_tickets, :group_ticket_permission)
    ticket.freshcaller_call.destroy
    ticket.notes.find_by_source(Account.current.helpdesk_sources.note_source_keys_by_token["meta"]).destroy
  end

  def test_verify_ticket_permission_for_non_freshcaller_ticket
    response = ActionDispatch::TestResponse.new
    @controller.response = response
    User.any_instance.stubs(:can_view_all_tickets?).returns(false).at_most_once
    User.any_instance.stubs(:group_ticket_permission).returns(false).at_most_once
    ticket = Helpdesk::Ticket.first
    @controller.send(:verify_ticket_permission, @agent, ticket)
    assert_equal 403, response.status
  ensure
    User.any_instance.unstub(:can_view_all_tickets, :group_ticket_permission)
  end
end
