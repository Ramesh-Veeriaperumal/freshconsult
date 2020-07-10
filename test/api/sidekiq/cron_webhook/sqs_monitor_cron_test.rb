require_relative '../../../../test/api/unit_test_helper'
require_relative '../../../test_helper'
require_relative '../../../test_transactions_fixtures_helper'
class SqsMonitorCronTest < ActionMailer::TestCase
  def teardown
    super
    AwsWrapper::SqsV2.unstub(:get_queue_attributes)
  end

  def test_escalation
    attributes = Aws::SQS::Types::GetQueueAttributesResult.new(attributes: { 'ApproximateNumberOfMessages' => '51'})
    AwsWrapper::SqsV2.stubs(:get_queue_attributes).returns(attributes)
    Mail::Message.any_instance.expects(:deliver).once
    CronWebhooks::SqsMonitor.new.perform(queue_name: 'facebook_realtime_queue', task_name: 'sqs_monitor')
  end

  def test_no_escalation
    attributes = Aws::SQS::Types::GetQueueAttributesResult.new(attributes: { 'ApproximateNumberOfMessages' => '49'})
    AwsWrapper::SqsV2.stubs(:get_queue_attributes).returns(attributes)
    Mail::Message.any_instance.expects(:deliver).never
    CronWebhooks::SqsMonitor.new.perform(queue_name: 'facebook_realtime_queue', task_name: 'sqs_monitor')
  end
end
