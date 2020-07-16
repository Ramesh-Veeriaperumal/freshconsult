module CronWebhooks
  class SocialCreateDynamodbTables < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_social_create_dynamodb_tables, retry: 0, dead: true, failures: :exhausted

    include Social::Util
    include Social::Constants
    include AwsWrapper::CloudWatchConstants

    def perform(args)
      perform_block(args) do
        create_dynamo_tables
      end
    end

    private

      def create_dynamo_tables
        # Create the tables for next week
        time = Time.now + 16.days # second table needed for wednesday
        TABLES.each_key do |table|
          schema = TABLES[table][:schema]
          properties = DYNAMO_DB_CONFIG[table]
          name  = Social::DynamoHelper.select_table(table, time)
          write = properties['write_capacity']

          Social::DynamoHelper.create_table(name, schema[:hash], schema[:range])

          options = {
            metric: METRIC_NAME[:write_capacity],
            resource_type: RESOURCE[:dynamo_db],
            threshold: write,
            statistic: STATISTIC[:maximum],
            alarms: [SNS['social_notification_topic']]
          }

          if Social::DynamoHelper.table_exists?(name)
            notify_social_mailer(nil, { table_name: name }, 'DynamoDb table created for next week')
            AwsWrapper::CloudWatch.create(name, options)
          else
            notify_social_mailer(nil, { table_name: name }, 'DynamoDb table not created for next week')
          end
        end
      end
  end
end
