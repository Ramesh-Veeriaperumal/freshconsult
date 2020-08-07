require_relative '../../../../test/api/unit_test_helper'
require_relative '../../../test_helper'
require_relative '../../../test_transactions_fixtures_helper'
class SqsMonitorCronTest < ActionMailer::TestCase
  def teardown
    super
    AwsWrapper::SqsV2.unstub(:get_queue_attributes)
  end

  def test_escalation
    AwsWrapper::SqsV2.stubs(:get_queue_attributes).returns({ 'ApproximateNumberOfMessages' => '51'})
    Mail::Message.any_instance.expects(:deliver).once
    CronWebhooks::SqsMonitor.new.perform(queue_name: 'facebook_realtime_queue', task_name: 'sqs_monitor')
  end

  def test_no_escalation
    AwsWrapper::SqsV2.stubs(:get_queue_attributes).returns({ 'ApproximateNumberOfMessages' => '0'})
    Mail::Message.any_instance.expects(:deliver).never
    CronWebhooks::SqsMonitor.new.perform(queue_name: 'facebook_realtime_queue', task_name: 'sqs_monitor')
  end
end
