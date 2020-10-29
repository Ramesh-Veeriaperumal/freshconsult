require_relative '../../../../test/api/unit_test_helper'
require_relative '../../../test_transactions_fixtures_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'twitter_test_helper.rb')
class TwitterCustomstreamCronWorkerTest < ActionView::TestCase
  include TwitterTestHelper
  def teardown
    cleanup_twitter_handles(@account)
    Account.unstub(:current)
    WebMock.disable_net_connect!
  end

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    create_test_twitter_handle(@account)
    WebMock.allow_net_connect!
  end

  def test_custom_stream_twitter_enqueue
    Social::CustomTwitterWorker.drain
    CronWebhooks::TwitterCustomStream.new.perform(type: 'trial', task_name: 'scheduler_custom_stream_twitter')
    refute Social::CustomTwitterWorker.jobs.empty?
  end
end
