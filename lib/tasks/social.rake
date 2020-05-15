namespace :social do
  
  desc "Create dynamoDB tables for the next week - Runs every Tuesday"
  task :create_dynamoDb_tables => :environment do
  
    include Social::Util
    include Social::Constants
    include AwsWrapper::CloudWatchConstants

    #Create the tables for next week
    time = Time.now + 16.days #second table needed for wednesday
    TABLES.keys.each do |table|
      schema = TABLES[table][:schema]
      properties = DYNAMO_DB_CONFIG[table]
      name  = Social::DynamoHelper.select_table(table, time)
      read  = properties["start_read_capacity"]
      write = properties["write_capacity"]

      Social::DynamoHelper.create_table(name, schema[:hash], schema[:range])
      
      options = {
        :metric         => METRIC_NAME[:write_capacity],
        :resource_type  => RESOURCE[:dynamo_db],
        :threshold      => write,
        :statistic      => STATISTIC[:maximum],
        :alarms         => [ SNS["social_notification_topic"] ]
      }

      unless Social::DynamoHelper.table_exists?(name)
        notify_social_dev("DynamoDb table not created for next week", {:table_name => name})
      else
        notify_social_dev("DynamoDb table created for next week", {:table_name => name})
        AwsWrapper::CloudWatch.create(name, options)
      end
    end
  end
  
  
  desc "Delete 2 weeks old dynamoDB tables - Runs every Thursday"
  task :delete_dynamoDb_tables => :environment do
    include Social::Constants
    include Social::Util

    time = Time.now - 16.days #2 weeks old table
    TABLES.keys.each do |table|
      name = Social::DynamoHelper.select_table(table, time)

      Social::DynamoHelper.delete_table(name)

      #verify if the tables exists
      if Social::DynamoHelper.table_exists?(name)
        notify_social_dev("DynamoDb table not deleted", {:table_name => name})
      else
        notify_social_dev("DynamoDb table deleted", {:table_name => name})
      end
    end
  end
end
