require_relative '../../../../test/api/unit_test_helper'
require_relative '../../../test_transactions_fixtures_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
Sidekiq::Testing.fake!
class ArchiveAutomationCronTest < ActionView::TestCase
  include AccountTestHelper

  def setup
    create_test_account if Account.first.nil?
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def test_archive_automation_with_account_id
    Archive::AccountTicketsWorker.drain
    Account.any_instance.stubs(:disable_archive_enabled?).returns(false)
    CronWebhooks::ArchiveAutomation.new.perform(account_id: Account.current.id, task_name: 'archive_automation')
    assert_equal true, Archive::AccountTicketsWorker.jobs.size >= 1, 'should enqueue for the passed account_id'
  end

  def test_archive_automation_with_shard_name
    Archive::AccountTicketsWorker.drain
    current_account_shard = ShardMapping.lookup_with_domain(Account.current.full_domain).shard_name
    Sharding.run_on_shard(current_account_shard) do
      Account.all.map(&:id)[0..4].each do |account_id|
        $redis_tickets.perform_redis_op('lpush', current_account_shard + '_archive', account_id)
      end
    end
    account_ids = $redis_tickets.perform_redis_op('lrange', current_account_shard + '_archive', 0, -1)
    Account.any_instance.stubs(:disable_archive_enabled?).returns(false)
    CronWebhooks::ArchiveAutomation.new.perform(shard_name: current_account_shard, task_name: 'archive_automation')
    assert_equal true, Archive::AccountTicketsWorker.jobs.size >= account_ids.count, 'should enqueue for all accounts in shard'
  end

  def test_archive_automation_without_any_params
    Archive::AccountTicketsWorker.drain
    current_account_shard = ShardMapping.lookup_with_domain(Account.current.full_domain).shard_name
    $redis_tickets.perform_redis_op('sadd', 'archive_automation_shards', current_account_shard)
    Sharding.run_on_shard(current_account_shard) do
      Account.all.map(&:id)[0..4].each do |account_id|
        $redis_tickets.perform_redis_op('lpush', current_account_shard + '_archive', account_id)
      end
    end
    account_ids = $redis_tickets.perform_redis_op('lrange', current_account_shard + '_archive', 0, -1)
    Account.any_instance.stubs(:disable_archive_enabled?).returns(false)
    CronWebhooks::ArchiveAutomation.new.perform(task_name: 'archive_automation')
    assert_equal true, Archive::AccountTicketsWorker.jobs.size >= account_ids.count, 'should enqueue for all accounts in whitelisted shard'
  end
end
