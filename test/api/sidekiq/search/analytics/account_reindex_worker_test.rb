require_relative '../../../unit_test_helper'
require 'sidekiq/testing'
require 'minitest/autorun'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'create_ticket_helper.rb')

class AccountReindexWorkerTest < ActionView::TestCase
  include AccountTestHelper
  include CreateTicketHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    5.times do
      create_ticket
    end
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_ticket_reindex_worker
    assert_nothing_raised do
      Search::Analytics::AccountReindexWorker.perform_async({})
    end
  end

  def test_last_indexed_time
    Search::Analytics::AccountReindexWorker.new.perform({})
    assert @account.account_additional_settings.additional_settings[:last_tickets_reindexed_count_analytics_time]
    assert_instance_of Time, @account.account_additional_settings.additional_settings[:last_tickets_reindexed_count_analytics_time]
  end

  def test_enqueu_tickets_reindex_worker
    Search::Analytics::TicketsReindexWorker.expects(:perform_async).once
    Search::Analytics::AccountReindexWorker.new.perform({})
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
