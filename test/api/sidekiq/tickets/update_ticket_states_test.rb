require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('spec', 'support', 'automations_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'note_test_helper.rb')

class UpdateTicketStatesTest < ActionView::TestCase
  include CoreTicketsTestHelper
  include UsersHelper
  include ControllerTestHelper
  include AutomationsHelper
  include NoteTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @agent = get_admin
    @agent.make_current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_ticket_state_worker_update_response_time
    user = add_new_user(@account)
    User.stubs(:current).returns(user)
    ticket = create_ticket
    User.unstub(:current)
    note = create_note(notable_id: ticket.id, private: false)
    input = {
      id: note.id,
      model_changes: { private: false },
      freshdesk_webhook: false,
      current_user_id: @agent.id
    }
    Tickets::UpdateTicketStatesWorker.new.perform(input)
    note.reload
    ticket_state = note.notable.ticket_states
    assert ticket_state.first_response_time == note.updated_at
    assert ticket_state.agent_responded_at == note.updated_at
  end

  def test_ticket_state_worker_without_model_changes
    user = add_new_user(@account)
    User.stubs(:current).returns(user)
    ticket = create_ticket
    User.unstub(:current)
    note = create_note(notable_id: ticket.id, private: false)
    input = {
      id: note.id,
      model_changes: nil,
      freshdesk_webhook: false,
      current_user_id: @agent.id
    }
    Tickets::UpdateTicketStatesWorker.new.perform(input)
    note.reload
    ticket_state = note.notable.ticket_states
    assert ticket_state.first_response_time == note.updated_at
    assert ticket_state.agent_responded_at == note.updated_at
  end

  def test_ticket_state_worker_with_invalid_note_id
    user = add_new_user(@account)
    User.stubs(:current).returns(user)
    ticket = create_ticket
    User.unstub(:current)
    note = create_note(notable_id: ticket.id, private: false)
    input = {
      id: 100,
      model_changes: nil,
      freshdesk_webhook: false,
      current_user_id: @agent.id
    }
    Tickets::UpdateTicketStatesWorker.new.perform(input)
    note.reload
    ticket_state = note.notable.ticket_states
    assert ticket_state.first_response_time.nil?
    assert ticket_state.agent_responded_at.nil?
  end

  def test_ticket_state_worker_with_private_note
    user = add_new_user(@account)
    User.stubs(:current).returns(user)
    ticket = create_ticket
    User.unstub(:current)
    note = create_note(notable_id: ticket.id, private: true)
    input = {
      id: note.id,
      model_changes: nil,
      freshdesk_webhook: false,
      current_user_id: @agent.id
    }
    Tickets::UpdateTicketStatesWorker.new.perform(input)
    note.reload
    ticket_state = note.notable.ticket_states
    assert ticket_state.first_response_time.nil?
    assert ticket_state.agent_responded_at.nil?
  end

  def test_ticket_state_worker_with_exception
    user = add_new_user(@account)
    User.stubs(:current).returns(user)
    ticket = create_ticket
    User.unstub(:current)
    note = create_note(notable_id: ticket.id, private: false)
    input = {
      id: note.id,
      model_changes: nil,
      freshdesk_webhook: false,
      current_user_id: @agent.id
    }
    assert_nothing_raised do
      Account.stubs(:current).raises(RuntimeError)
      Tickets::UpdateTicketStatesWorker.new.perform(input)
      Account.unstub(:current)
    end
    note.reload
    ticket_state = note.notable.ticket_states
    assert ticket_state.first_response_time.nil?
    assert ticket_state.agent_responded_at.nil?
  end

  def test_ticket_state_worker_with_requester_response
    user = add_new_user(@account)
    User.stubs(:current).returns(user)
    ticket = create_ticket
    User.unstub(:current)
    note = create_note(notable_id: ticket.id, private: false)
    input = {
      id: note.id,
      model_changes: nil,
      freshdesk_webhook: false,
      current_user_id: @agent.id
    }
    Tickets::UpdateTicketStatesWorker.new.perform(input)
    note1 = create_note(notable_id: ticket.id, private: false, incoming: true, user_id: user.id)
    input = {
      id: note1.id,
      model_changes: nil,
      freshdesk_webhook: false,
      current_user_id: user.id
    }
    Tickets::UpdateTicketStatesWorker.new.perform(input)
    note1.reload
    ticket_state = note1.notable.ticket_states
    assert ticket_state.requester_responded_at == note1.updated_at
    assert ticket_state.inbound_count == 2
  end

  def test_ticket_state_worker_with_outbount_email
    user = add_new_user(@account)
    User.stubs(:current).returns(user)
    ticket = create_ticket
    User.unstub(:current)
    note = create_note(notable_id: ticket.id, private: false, incoming: false, source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email'])
    input = {
      id: note.id,
      model_changes: nil,
      freshdesk_webhook: false,
      current_user_id: @agent.id
    }
    Tickets::UpdateTicketStatesWorker.new.perform(input)
    note1 = create_note(notable_id: ticket.id, private: false, incoming: false, source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email'], user_id: user.id)
    input = {
      id: note1.id,
      model_changes: nil,
      freshdesk_webhook: false,
      current_user_id: user.id
    }
    Tickets::UpdateTicketStatesWorker.new.perform(input)
    note1.reload
    ticket_state = note1.notable.ticket_states
    assert ticket_state.requester_responded_at == note1.updated_at
    assert ticket_state.inbound_count == 2
  end
end
