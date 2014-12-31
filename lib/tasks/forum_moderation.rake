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

  desc "Create tables in dynamo"
  task :create_tables, [:year, :month] => :environment do |t,args|
    Community::DynamoTables.create(args.to_hash)
  end

  desc "Drop outdated tables in dynamo"
  task :drop_tables, [:year, :month] => :environment do |t, args|
    Community::DynamoTables.drop(args.to_hash)
  end
end