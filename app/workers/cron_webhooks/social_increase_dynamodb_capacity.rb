module CronWebhooks
  class SocialIncreaseDynamodbCapacity < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_social_increase_dynamodb_capacity, retry: 0, dead: true, failures: :exhausted

    include Social::Util
    include Social::Constants
    include AwsWrapper::CloudWatchConstants

    def perform(args)
      perform_block(args) do
        increase_dynamo_capacity
      end
    end

    private

      def increase_dynamo_capacity
        time = Time.now + 3.days # table form which we will start reading on wednesday
        TABLES.each_key do |table|
          properties = DYNAMO_DB_CONFIG[table]
          name = Social::DynamoHelper.select_table(table, time)
          start_read = properties['start_read_capacity']
          end_read = properties['final_read_capacity']
          write_capacity = properties['write_capacity']

          Social::DynamoHelper.increase_rw_table(name, start_read, end_read, write_capacity)

          options = {
            metric: METRIC_NAME[:read_capacity],
            resource_type: RESOURCE[:dynamo_db],
            threshold: end_read,
            statistic: STATISTIC[:maximum],
            alarms: [SNS['social_notification_topic']]
          }

          msg = {
            table_name: name,
            start_read: start_read,
            end_read: end_read
          }
          notify_social_dev('Read capacity increased for table', msg)

          AwsWrapper::CloudWatch.create(name, options)
        end
      end
  end
end
