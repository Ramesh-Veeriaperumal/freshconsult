require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'webmock/minitest'
WebMock.allow_net_connect!
Sidekiq::Testing.fake!

require Rails.root.join('test', 'api', 'sidekiq', 'create_ticket_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'note_test_helper.rb')

class DetectThankYouNoteWorkerTest < ActionView::TestCase
  include CreateTicketHelper
  include NoteTestHelper

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

  def test_thank_you_note_feedback_worker
    WebMock.allow_net_connect!
    @ticket = create_ticket
    note = create_test_note
    args = { ticket_id: @ticket.id }
    parsed_response = { 'reopen' => 0, 'confidence' => 99.77472623583164 }
    thank_you_note = { note_id: note.id, response: parsed_response.symbolize_keys }
    @ticket.schema_less_ticket.thank_you_notes = []
    @ticket.schema_less_ticket.thank_you_notes.push(thank_you_note)
    @ticket.schema_less_ticket.save!
    response_stub = ResponseStub.new({ 'status' => 1 }.to_json, 200)
    HTTParty.stubs(:post).returns(response_stub)
    ::Freddy::DetectThankYouNoteFeedbackWorker.new.perform(args)
    assert_equal 0, ::Freddy::DetectThankYouNoteFeedbackWorker.jobs.size
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
end
