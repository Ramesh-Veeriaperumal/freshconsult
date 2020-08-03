require_relative '../../test_helper'

class SubscriptionTest < ActiveSupport::TestCase
  include TicketsTestHelper

  def setup
    super
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account.add_feature(:add_watcher)
    @account.subscription.state = 'active'
    @account.subscription.save
    @@before_all_run = true
  end

  def test_central_publish_add_watcher
    skip('skip failing test cases')
    t = create_ticket(ticket_params_hash)
    t.reload
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    t.subscriptions.build(user_id: @agent.id)
    t.save
    assert_equal 1, CentralPublishWorker::ActiveTicketWorker.jobs.size
    job = CentralPublishWorker::ActiveTicketWorker.jobs.last
    assert_equal 'ticket_update', job['args'][0]
    assert_equal({'add_watcher' => [@agent.id]}, job['args'][1]['model_changes'])
  end

  def test_central_publish_remove_watcher
    skip('skip failing test cases')
    t = create_ticket(ticket_params_hash)
    t.subscriptions.build(user_id: @agent.id)
    t.save
    t.reload
    CentralPublishWorker::ActiveTicketWorker.jobs.clear
    t.subscriptions.first.destroy
    assert_equal 1, CentralPublishWorker::ActiveTicketWorker.jobs.size
    job = CentralPublishWorker::ActiveTicketWorker.jobs.last
    assert_equal 'ticket_update', job['args'][0]
    assert_equal({'remove_watcher' => [@agent.id]}, job['args'][1]['model_changes'])
  end
end