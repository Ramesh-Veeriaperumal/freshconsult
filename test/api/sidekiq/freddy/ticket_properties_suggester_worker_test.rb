require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'webmock/minitest'
WebMock.allow_net_connect!
Sidekiq::Testing.fake!

require Rails.root.join('test', 'api', 'sidekiq', 'create_ticket_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'note_test_helper.rb')

class TicketPropertiesSuggesterWorkerTest < ActionView::TestCase
  include CreateTicketHelper

  def setup
    @account = Account.first.presence || create_test_account
    Account.stubs(:current).returns(@account)
    @account.stubs(:ticket_properties_suggester_enabled?).returns(true)

  end

  def teardown
    Account.unstub(:current)
    super
  end

  class ResponseStub
    def initialize(parsed_response, code)
      @parsed_response = parsed_response
      @code = code
    end
    attr_accessor :parsed_response, :code
  end

  def test_ticket_properties_suggester_worker
    WebMock.allow_net_connect!
    @ticket = create_ticket
    args = { ticket_id: @ticket.id, action: 'predict', dispatcher_set_priority: false }
    response_stub = ResponseStub.new({ 'priority' => { 'response' => 'Medium', 'conf' => 'high' }, 'ticket_type' => { 'response' => "L1 - How To's", 'conf' => 'high' }, 'group_id' => { 'response' => '246803', 'conf' => 'low' } }, 200)
    HTTParty.stubs(:post).returns(response_stub)
    ::Freddy::TicketPropertiesSuggesterWorker.new.perform(args)
    @ticket.reload
    assert @ticket.schema_less_ticket.ticket_properties_suggester_hash.present?
    WebMock.disable_net_connect!
  ensure
    Account.unstub(:current)
    HTTParty.unstub(:post)
  end  

  def test_ticket_properties_suggester_feature_disabled?
    WebMock.allow_net_connect!    
    @account.stubs(:ticket_properties_suggester_enabled?).returns(false)    
    jobs_count = ::Freddy::TicketPropertiesSuggesterWorker.jobs.size
    ticket = Helpdesk::Ticket.new
    ticket.source = 1
    ticket.requester = User.first
    ticket.save!
    current_jobs_count = ::Freddy::TicketPropertiesSuggesterWorker.jobs.size
    assert jobs_count == current_jobs_count 
    @account.unstub(:ticket_properties_suggester_enabled?)
    WebMock.disable_net_connect!
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
end
