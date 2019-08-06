module CronWebhooks
  class SocialReduceDynamodbCapacity < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_social_reduce_dynamodb_capacity, retry: 0, dead: true, failures: :exhausted

    include Social::Util
    include Social::Constants

    def perform(args)
      perform_block(args) do
        reduce_dynamo_capacity
      end
    end

    private

      def reduce_dynamo_capacity
        time   = Time.now - 16.days # 2 weeks old table
        alarms = []
        TABLES.each_key do |table|
          name = Social::DynamoHelper.select_table(table, time)
          Social::DynamoHelper.update_rw_table(name, 1, 1)
          alarms << "#{name}_alarm"
          notify_social_dev('Read and write capacity reduced for tables', table_name: name)
        end
        AwsWrapper::CloudWatch.delete(alarms)
      end
  end
end
