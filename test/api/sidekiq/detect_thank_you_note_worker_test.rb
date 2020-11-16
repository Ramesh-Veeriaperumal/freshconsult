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

  BLACKLISTED_THANK_YOU_DETECTOR_NOTE_SOURCES = Helpdesk::Source.note_blacklisted_thank_you_detector_note_sources

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
    def initialize(parsed_response, code, headers = { 'Content-Type' => 'application/json' })
      @parsed_response = parsed_response
      @code = code
      @headers = headers
    end
    attr_accessor :parsed_response, :code, :headers
  end

  def test_thank_you_note_worker_performed_by_agent
    WebMock.allow_net_connect!
    @ticket = create_ticket
    note = create_test_note
    args = { ticket_id: @ticket.id, note_id: note.id }
    response_stub = ResponseStub.new({ 'reopen' => 0, 'confidence' => 99.77472623583164 }, 200)
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
    response_stub = ResponseStub.new({ 'reopen' => 0, 'confidence' => 99.77472623583164, 'text' => 'sample text' }, 200)
    HTTParty.stubs(:post).returns(response_stub)
    ::Freddy::DetectThankYouNoteWorker.new.perform(args) if detect_thank_you_note?(note)
    note.reload
    @ticket.reload
    assert_equal true, note.schema_less_note.thank_you_note.present?
    note.schema_less_note.thank_you_note.must_match_json_expression('reopen' => 0, 'confidence' => 99.77472623583164)
    @ticket.schema_less_ticket.thank_you_notes[0][:response].must_match_json_expression('reopen' => 0, 'confidence' => 99.77472623583164)
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
    response_stub = ResponseStub.new({ 'reopen' => 0, 'confidence' => 99.77472623583164 }, 200)
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
    response_stub = ResponseStub.new({ 'reopen' => 0, 'confidence' => 99.77472623583164 }, 200)
    HTTParty.stubs(:post).returns(response_stub)
    ::Freddy::DetectThankYouNoteWorker.new.perform(args) if detect_thank_you_note?(note) && recently_created_note?(note)
    assert_equal 0, ::Freddy::DetectThankYouNoteWorker.jobs.size
    WebMock.disable_net_connect!
  ensure
    Account.unstub(:current)
    HTTParty.unstub(:post)
  end

  def test_thank_you_note_worker_invoke_observer
    WebMock.allow_net_connect!
    @ticket = create_ticket
    ::Tickets::ObserverWorker.clear
    note = create_test_note
    user = add_new_user(@account)
    note.user_id = user.id
    note.save!
    args = { ticket_id: @ticket.id, note_id: note.id }
    response_stub = ResponseStub.new({ 'reopen' => 0, 'confidence' => 99.77472623583164 }, 200)
    HTTParty.stubs(:post).returns(response_stub)
    ::Freddy::DetectThankYouNoteWorker.new.perform(args) if detect_thank_you_note?(note)
    note.reload
    assert_equal true, note.schema_less_note.thank_you_note.present?
    current_jobs_count = ::Tickets::ObserverWorker.jobs.size
    assert_equal current_jobs_count, 1
    WebMock.disable_net_connect!
  ensure
    Account.unstub(:current)
    HTTParty.unstub(:post)
  end

  def test_thank_you_note_worker_invoke_observer_with_feature_disabled
    @account.stubs(:detect_thank_you_note_enabled?).returns(false)
    WebMock.allow_net_connect!
    ::Tickets::ObserverWorker.clear
    @ticket = create_ticket
    note = create_test_note
    user = add_new_user(@account)
    note.user_id = user.id
    note.save!
    args = { ticket_id: @ticket.id, note_id: note.id }
    response_stub = ResponseStub.new({ 'reopen' => 0, 'confidence' => 99.77472623583164 }, 200)
    HTTParty.stubs(:post).returns(response_stub)
    ::Freddy::DetectThankYouNoteWorker.new.perform(args) if Account.current.detect_thank_you_note_enabled?
    note.reload
    assert_equal false, note.schema_less_note.thank_you_note.present?
    current_jobs_count = ::Tickets::ObserverWorker.jobs.size
    assert_equal current_jobs_count, 0
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
        source: Helpdesk::Source::EMAIL
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
