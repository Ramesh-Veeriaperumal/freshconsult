namespace :forum_moderation do

  desc "Polling the sqs to moderate the posts"
  task :scan => :environment do
    $sqs_forum_moderation.poll(:initial_timeout => false, :batch_size => 10) do |sqs_msg|

      puts "** Got ** #{sqs_msg.body} **"
      msg_attributes = JSON.parse(sqs_msg.body)['sqs_post']

      Sharding.select_shard_of(msg_attributes['account_id']) do

        Community::Moderation::QueuedPost.new(msg_attributes).analyze
        
      end
      Account.reset_current_account

      puts "** Done ** #{sqs_msg.body} **"
    end
  end

  desc "Create(construct and activate) tables in dynamo"
  task :create_tables => :environment do |t|
    Community::DynamoTables.create
  end

  desc "Activate specified tables in dynamo"
  task :activate_tables, [:year, :month] => :environment do |t, args|
    Community::DynamoTables.activate(args.to_hash)
  end
  
  desc "Construct specified tables in dynamo"
  task :construct_tables, [:year, :month] => :environment do |t, args|
    Community::DynamoTables.construct(args.to_hash)
  end

  desc "Drop(Retire and delete) outdated tables in dynamo"
  task :drop_tables => :environment do |t|
    Community::DynamoTables.drop
  end

  desc "Retire outdated tables in dynamo"
  task :retire_tables, [:year, :month] => :environment do |t, args|
    Community::DynamoTables.retire(args.to_hash)
  end
  
  desc "Delete outdated tables in dynamo"
  task :delete_tables, [:year, :month] => :environment do |t, args|
    Community::DynamoTables.delete(args.to_hash)
  end
end