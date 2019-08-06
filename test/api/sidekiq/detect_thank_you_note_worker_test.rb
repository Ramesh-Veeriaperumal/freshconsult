require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'webmock/minitest'
WebMock.allow_net_connect!
Sidekiq::Testing.fake!

require Rails.root.join('test', 'api', 'sidekiq', 'create_ticket_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'note_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

class DetectThankYouNoteWorkerTest < ActionView::TestCase
  include CreateTicketHelper
  include NoteTestHelper
  include AccountTestHelper
  include CoreUsersTestHelper

  BLACKLISTED_THANK_YOU_DETECTOR_NOTE_SOURCES = [Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['feedback'], Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['meta'], Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['summary'],
                                                 Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['automation_rule_forward'], Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['automation_rule']]

  def setup
    @account = Account.first.presence || create_test_account
    Account.stubs(:current).returns(@account)
    @account.stubs(:detect_thank_you_note_enabled?).returns(true)
  end

  def teardown
    Account.unstub(:current)
    @account.unstub(:detect_thank_you_note_enabled?)
    super
  end

  class ResponseStub
    def initialize(parsed_response, code)
      @parsed_response = parsed_response
      @code = code
    end
    attr_accessor :parsed_response, :code
  end

  def test_thank_you_note_worker_performed_by_agent
    WebMock.allow_net_connect!
    @ticket = create_ticket
    note = create_test_note
    args = { ticket_id: @ticket.id, note_id: note.id }
    response_stub = ResponseStub.new({ 'reopen' => 0, 'confidence' => 99.77472623583164 }.to_json, 200)
    HTTParty.stubs(:post).returns(response_stub)
    ::Freddy::DetectThankYouNoteWorker.new.perform(args) if detect_thank_you_note?(note)
    note.reload
    assert_equal false, note.schema_less_note.thank_you_note.present?
    WebMock.disable_net_connect!
  ensure
    Account.unstub(:current)
    HTTParty.unstub(:post)
  end

  def test_thank_you_note_worker_performed_by_requester
    WebMock.allow_net_connect!
    @ticket = create_ticket
    note = create_test_note
    user = add_new_user(@account)
    note.user_id = user.id
    note.save!
    args = { ticket_id: @ticket.id, note_id: note.id }
    response_stub = ResponseStub.new({ 'reopen' => 0, 'confidence' => 99.77472623583164 }.to_json, 200)
    HTTParty.stubs(:post).returns(response_stub)
    ::Freddy::DetectThankYouNoteWorker.new.perform(args) if detect_thank_you_note?(note)
    note.reload
    assert_equal true, note.schema_less_note.thank_you_note.present?
    WebMock.disable_net_connect!
  ensure
    Account.unstub(:current)
    HTTParty.unstub(:post)
  end

  def test_thank_you_note_worker_for_note_created_earlier
    WebMock.allow_net_connect!
    @ticket = create_ticket
    note = create_note(note_params.merge!(created_at: 2.hours.ago))
    user = add_new_user(@account)
    note.user_id = user.id
    note.save!
    args = { ticket_id: @ticket.id, note_id: note.id }
    response_stub = ResponseStub.new({ 'reopen' => 0, 'confidence' => 99.77472623583164 }.to_json, 200)
    HTTParty.stubs(:post).returns(response_stub)
    ::Freddy::DetectThankYouNoteWorker.new.perform(args) if detect_thank_you_note?(note) && recently_created_note?(note)
    assert_equal 0, ::Freddy::DetectThankYouNoteWorker.jobs.size
    WebMock.disable_net_connect!
  ensure
    Account.unstub(:current)
    HTTParty.unstub(:post)
  end

  def test_thank_you_note_worker_for_note_empty_body
    WebMock.allow_net_connect!
    @ticket = create_ticket
    note_params[:body] = ''
    note = create_note(note_params)
    user = add_new_user(@account)
    note.user_id = user.id
    note.save!
    args = { ticket_id: @ticket.id, note_id: note.id }
    response_stub = ResponseStub.new({ 'reopen' => 0, 'confidence' => 99.77472623583164 }.to_json, 200)
    HTTParty.stubs(:post).returns(response_stub)
    ::Freddy::DetectThankYouNoteWorker.new.perform(args) if detect_thank_you_note?(note) && recently_created_note?(note)
    assert_equal 0, ::Freddy::DetectThankYouNoteWorker.jobs.size
    WebMock.disable_net_connect!
  ensure
    Account.unstub(:current)
    HTTParty.unstub(:post)
  end

  private

    def create_ticket
      create_test_ticket(ticket_params)
    end

    def ticket_params
      {
        email: 'sample@freshdesk.com',
        source: Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:email]
      }
    end

    def create_test_note
      create_note(note_params)
    end

    def note_params
      {
        account_id: Account.current.id,
        user_id: Agent.first.user_id,
        ticket_id: @ticket.id,
        private: true,
        body: 'Thank you'
      }
    end

    def detect_thank_you_note?(note)
      !BLACKLISTED_THANK_YOU_DETECTOR_NOTE_SOURCES.include?(note.source) && note.user.customer?
    end

    def recently_created_note?(note)
      Time.now - note.created_at < 1.hour
    end
end
