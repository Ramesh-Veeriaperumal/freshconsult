namespace :social do
  
  desc "Create dynamoDB tables for the next week - Runs every Tuesday"
  task :create_dynamoDb_tables => :environment do
  
    include Social::Util
    include Social::Constants
    include AwsWrapper::CloudWatchConstants

    #Create the tables for next week
    time = Time.now + 9.days #second table needed for wednesday
    TABLES.keys.each do |table|
      schema = TABLES[table][:schema]
      properties = DYNAMO_DB_CONFIG[table]
      name  = Social::DynamoHelper.select_table(table, time)
      read  = properties["start_read_capacity"]
      write = properties["write_capacity"]

      Social::DynamoHelper.create_table(name, schema[:hash], schema[:range], read, write)
      
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

    time = Time.now - 9.days #2 weeks old table
    TABLES.keys.each do |table|
      schema = TABLES[table][:schema]
      properties = DYNAMO_DB_CONFIG[table]
      name = Social::DynamoHelper.select_table(table, time)

      #Dont delete the actual table for now. Pretend delete
      #Social::DynamoHelper.delete_table(name)

      #verify if the tables exists
      if Social::DynamoHelper.table_exists?(name)
        notify_social_dev("DynamoDb table not deleted", {:table_name => name})
      else
        notify_social_dev("DynamoDb table deleted", {:table_name => name})
      end
    end
  end
  
  desc "Increase the read capacity of the table which will be used on Wednesday - Runs every Tuesday"
  task :increase_dynamoDb_capacity => :environment do
    
    include Social::Util
    include Social::Constants
    include AwsWrapper::CloudWatchConstants

    time = Time.now + 3.days #table form which we will start reading on wednesday
    TABLES.keys.each do |table|
      properties = DYNAMO_DB_CONFIG[table]
      name = Social::DynamoHelper.select_table(table, time)
      start_read = properties["start_read_capacity"]
      end_read = properties["final_read_capacity"]
      write_capacity = properties["write_capacity"]

      Social::DynamoHelper.increase_rw_table(name, start_read, end_read, write_capacity)
      
      options = {
        :metric         => METRIC_NAME[:read_capacity],
        :resource_type  => RESOURCE[:dynamo_db],
        :threshold      => end_read,
        :statistic      => STATISTIC[:maximum],
        :alarms         => [ SNS["social_notification_topic"] ]
      }
      
      
      msg = {
        :table_name => name,
        :start_read => start_read,
        :end_read   => end_read
      }
      notify_social_dev("Read capacity increased for table", msg)
      
      AwsWrapper::CloudWatch.create(name, options)
    end
  end
  
  desc "Reduce and write capacity of the tables that will not be used anymore"
  task :reduce_dynamoDb_capacity => :environment do
    include Social::Constants
    include Social::Util

    time   = Time.now - 9.days #2 weeks old table
    alarms = []
    TABLES.keys.each do |table|
      name = Social::DynamoHelper.select_table(table, time)
      Social::DynamoHelper.update_rw_table(name, 1, 1)
      alarms << "#{name}_alarm"
      
      notify_social_dev("Read and write capacity reduced for tables", {:table_name => name})
    end
    
    AwsWrapper::CloudWatch.delete(alarms)
  end
  
end
