namespace :twitter do
  desc 'Check for New twitter feeds..'

  PREMIUM_ACC_IDS = {:staging => [390], :production => [18685,39190]}

  desc "Fetch DMs for twitter handles"
  task :fetch => :environment do
    queue_name = "TwitterWorker"
    if queue_empty?(queue_name)
      puts "Twitter Queue is empty... queuing at #{Time.zone.now}"
      Sharding.run_on_all_slaves do
        Account.active_accounts.each do |account|
          next if check_if_premium?(account) || account.twitter_handles.empty?
         	Resque.enqueue(Social::Twitter::Workers::DirectMessage, {:account_id => account.id})
        end
      end
    else
    	puts "Twitter Queue is already running . skipping at #{Time.zone.now}"
    end
    puts "Twitter task closed at #{Time.zone.now}"
  end

  desc "Fetch DMs for twitter handles at a faster rate - 'premium' accounts"
  task :premium => :environment do
    queue_name = "premium_twitter_worker"
    premium_acc_ids = Rails.env.production? ? PREMIUM_ACC_IDS[:production] : PREMIUM_ACC_IDS[:staging]
    if queue_empty?(queue_name)
      premium_acc_ids.each do |account_id|
        Resque.enqueue(Social::Twitter::Workers::DirectMessage::Premium, {:account_id => account_id})
      end
    else
      puts "Premium Twitter Worker is already running. skipping at #{Time.zone.now}"
    end
  end

  desc "Create dynamoDB tables for the next week - Runs every Tuesday"
  task :create_dynamoDb_tables => :environment do
    include Social::Constants
    include Social::Util

    #Create the tables for next week
    time = Time.now + 9.days #second table needed for wednesday
    TABLES.keys.each do |table|
      schema = TABLES[table][:schema]
      properties = DYNAMO_DB_CONFIG[table]
      name = Social::DynamoHelper.select_table(table, time)

      Social::DynamoHelper.create_table(name, schema[:hash], schema[:range], properties["read_capacity"], properties["write_capacity"])

      unless Social::DynamoHelper.table_exists?(name)
        notify_social_dev("DynamoDb table not created for next week", {:table_name => name})
      else
        notify_social_dev("DynamoDb table created for next week", {:table_name => name})
      end
    end
  end

  desc "Delete 2 weeks old dynamoDB tables - Runs every Thursday"
  task :delete_dynamoDb_tables => :environment do
    include Social::Constants
    include Social::Util

    #Create the tables for next week
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


  def queue_empty?(queue_name)
    queue_length = Resque.redis.llen "queue:#{queue_name}"
    puts "current #{queue_name} length is #{queue_length}"
    queue_length < 1
  end

  def check_if_premium?(account)
    Rails.env.production? ? PREMIUM_ACC_IDS[:production].include?(account.id) :
                            PREMIUM_ACC_IDS[:staging].include?(account.id)
  end

end
