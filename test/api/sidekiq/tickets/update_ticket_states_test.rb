require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('spec', 'support', 'user_helper.rb')
require Rails.root.join('spec', 'support', 'automations_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'tickets_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'note_test_helper.rb')
['test_case_methods.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

class UpdateTicketStatesTest < ActionView::TestCase
  include CoreTicketsTestHelper
  include UsersHelper
  include ControllerTestHelper
  include AutomationsHelper
  include NoteTestHelper
  include TestCaseMethods

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

  def get_update_ticket_states_worker_payload
    user = add_new_user(@account)
    User.stubs(:current).returns(user)
    @ticket = create_ticket
    User.unstub(:current)
    @note = create_note(notable_id: @ticket.id, private: false, incoming: false, source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['email'])
    {
      id: @note.id,
      model_changes: nil,
      freshdesk_webhook: false,
      current_user_id: @agent.id
    }
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

  def test_update_first_response_with_rails_lock
    Tickets::UpdateTicketStatesWorker.new.perform(get_update_ticket_states_worker_payload)
    @ticket.update_attributes(status: 3)
    reports_hash = @ticket.schema_less_ticket.reports_hash
    assert_equal 3, @ticket.status
    assert_equal @note.id, reports_hash['first_response_id']
    assert_equal @agent.id, reports_hash['first_response_agent_id']
  end

  def test_update_first_response_with_rails_lock_exception
    input = get_update_ticket_states_worker_payload
    status = @ticket.status
    Tickets::UpdateTicketStatesWorker.new.perform(input)
    stub_const(LockVersion::Utility, 'MAX_RETRY_COUNT', 0) do
      assert_raises ActiveRecord::StaleObjectError do
        @ticket.update_attributes(status: 3)
      end
    end
    @ticket.reload
    reports_hash = @ticket.schema_less_ticket.reports_hash
    assert_equal status, @ticket.status
    assert_equal @note.id, reports_hash['first_response_id']
    assert_equal @agent.id, reports_hash['first_response_agent_id']
  end

  def test_update_schema_less_ticket_with_lock_column_null_in_database
    Helpdesk::SchemaLessTicket.lock_optimistically = false
    get_update_ticket_states_worker_payload
    Helpdesk::SchemaLessTicket.lock_optimistically = true
    @ticket.schema_less_ticket.save!
    @ticket.reload
    assert_equal 1, @ticket.schema_less_ticket.int_tc05
  end

  def test_destroy_ticket_with_rails_lock
    Tickets::UpdateTicketStatesWorker.new.perform(get_update_ticket_states_worker_payload)
    @ticket.destroy
    assert_raises ActiveRecord::RecordNotFound do
      @ticket.reload
    end
  end

  def test_destroy_ticket_with_rails_lock_exception
    Tickets::UpdateTicketStatesWorker.new.perform(get_update_ticket_states_worker_payload)
    stub_const(LockVersion::Utility, 'MAX_RETRY_COUNT', 0) do
      assert_raises ActiveRecord::StaleObjectError do
        @ticket.destroy
      end
    end
    assert_nothing_raised { @ticket.reload }
    reports_hash = @ticket.schema_less_ticket.reports_hash
    assert_equal @note.id, reports_hash['first_response_id']
    assert_equal @agent.id, reports_hash['first_response_agent_id']
  end

  def test_destroy_ticket_with_lock_column_null_in_database
    Helpdesk::SchemaLessTicket.lock_optimistically = false
    get_update_ticket_states_worker_payload
    Helpdesk::SchemaLessTicket.lock_optimistically = true
    @ticket = @account.tickets.find(@ticket.id)
    @ticket.destroy
    assert_raises ActiveRecord::RecordNotFound do
      @ticket.reload
    end
  end
end
