require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'webmock/minitest'
WebMock.allow_net_connect!
Sidekiq::Testing.fake!

require Rails.root.join('test', 'api', 'sidekiq', 'create_ticket_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'note_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class DetectThankYouNoteWorkerTest < ActionView::TestCase
  include CreateTicketHelper
  include NoteTestHelper
  include AccountTestHelper

  def setup
    @account = Account.first.presence || create_test_account
    Account.stubs(:current).returns(@account)
  end

  def teardown
    Account.unstub(:current)
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

  def test_thank_you_note_worker
    WebMock.allow_net_connect!
    @ticket = create_ticket
    note = create_test_note
    args = { ticket_id: @ticket.id, note_id: note.id }
    response_stub = ResponseStub.new({ 'reopen' => 0, 'confidence' => 99.77472623583164 }, 200)
    HTTParty.stubs(:post).returns(response_stub)
    ::Freddy::DetectThankYouNoteWorker.new.perform(args)
    note.reload    
    assert note.schema_less_note.thank_you_note.present?
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
