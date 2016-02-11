namespace :twitter do

  desc "Increase the read capacity of the table which will be used on Wednesday - Runs every Tuesday"
  task :increase_dynamoDb_capacity => :environment do
    include Social::Constants
    include Social::Util

    time = Time.now + 3.days #table form which we will start reading on wednesday
    TABLES.keys.each do |table|
      schema = TABLES[table][:schema]
      properties = DYNAMO_DB_CONFIG[table]
      name = Social::DynamoHelper.select_table(table, time)
      start_read = properties["start_read_capacity"]
      end_read = properties["final_read_capacity"]
      write_capacity = properties["write_capacity"]

      Social::DynamoHelper.update_rw_table(name, schema[:hash], schema[:range], start_read, end_read, write_capacity)

      msg = {
        :table_name => name,
        :start_read => start_read,
        :end_read   => end_read
      }
      notify_social_dev("Read capacity increased for table", msg)
    end
  end

  def queue_empty?(queue_name)
    queue_length = Resque.redis.llen "queue:#{queue_name}"
    puts "current #{queue_name} length is #{queue_length}"
    queue_length < 1
  end

end
