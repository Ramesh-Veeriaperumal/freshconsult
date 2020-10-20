require_relative '../../../unit_test_helper'
require 'sidekiq/testing'
require 'minitest/autorun'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'create_ticket_helper.rb')

class TicketsReindexWorkerTest < ActionView::TestCase
  include AccountTestHelper
  include CreateTicketHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_ticket_reindex_worker
    assert_nothing_raised do
      ticket_ids = []
      no_of_ticket = 5
      no_of_ticket.times do
        ticket = create_ticket
        ticket_ids << [ticket.id, ticket.updated_at.to_f * 1_000_000]
      end
      ::Search::Dashboard::Count.any_instance.expects(:index_es_count_document).times(no_of_ticket)
      Search::Analytics::TicketsReindexWorker.new.perform(ticket_ids)
    end
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
