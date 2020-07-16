require_relative '../../../../test/api/unit_test_helper'
require_relative '../../../test_helper'
require_relative '../../../test_transactions_fixtures_helper'
class SqsMonitorCronTest < ActionMailer::TestCase
  def teardown
    super
    AWS::SQS.any_instance.unstub(:approximate_number_of_messages)
    AWS::SQS::QueueCollection.any_instance.unstub(:named)
  end

  def test_escalation
    AWS::SQS.any_instance.stubs(:approximate_number_of_messages).returns(51)
    AWS::SQS::QueueCollection.any_instance.stubs(:named).returns(AWS::SQS.new)
    Mail::Message.any_instance.expects(:deliver).once
    CronWebhooks::SqsMonitor.new.perform(queue_name: 'facebook_realtime_queue', task_name: 'sqs_monitor')
  end

  def test_no_escalation
    AWS::SQS.any_instance.stubs(:approximate_number_of_messages).returns(49)
    AWS::SQS::QueueCollection.any_instance.stubs(:named).returns(AWS::SQS.new)
    Mail::Message.any_instance.expects(:deliver).never
    CronWebhooks::SqsMonitor.new.perform(queue_name: 'facebook_realtime_queue', task_name: 'sqs_monitor')
  end
end
