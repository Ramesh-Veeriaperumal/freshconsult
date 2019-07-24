module CronWebhooks
  class SocialDeleteDynamodbTables < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_social_delete_dynamodb_tables, retry: 0, dead: true, failures: :exhausted

    include Social::Constants
    include Social::Util

    def perform(args)
      perform_block(args) do
        delete_dynamo_tables
      end
    end

    private

      def delete_dynamo_tables
        time = Time.now - 16.days # 2 weeks old table
        TABLES.each_key do |table|
          name = Social::DynamoHelper.select_table(table, time)
          Social::DynamoHelper.delete_table(name)

          # verify if the tables exists
          if Social::DynamoHelper.table_exists?(name)
            notify_social_dev('DynamoDb table not deleted', table_name: name)
          else
            notify_social_dev('DynamoDb table deleted', table_name: name)
          end
        end
      end
  end
end
