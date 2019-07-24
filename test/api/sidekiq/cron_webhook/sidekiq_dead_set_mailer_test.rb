require_relative '../../../../test/api/unit_test_helper'
require_relative '../../../test_helper'
require_relative '../../../test_transactions_fixtures_helper'
class SidekiqDeadSetMailer < ActionMailer::TestCase
  def teardown
    super
    Sidekiq::DeadSet.any_instance.unstub(:size)
  end

  def test_deadset_mailer
    Sidekiq::DeadSet.any_instance.stubs(:size).returns(10_000)
    Mail::Message.any_instance.expects(:deliver).once
    CronWebhooks::SidekiqDeadSetMailer.new.perform(task_name: 'sidekiq_bg_fetch_dead_jobs')
  end

  def test_deadset_mailer_no_mail
    Sidekiq::DeadSet.any_instance.stubs(:size).returns(10)
    Mail::Message.any_instance.expects(:deliver).never
    CronWebhooks::SidekiqDeadSetMailer.new.perform(task_name: 'sidekiq_bg_fetch_dead_jobs')
  end
end
