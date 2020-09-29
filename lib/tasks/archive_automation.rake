namespace :archive_automation do
  desc 'This task archives all closed tickets with no activities in the last n days.
        It also accepts an array of shard_names to run archive specifically in those shards'
  task :archive_automation_tickets, [:shard] => :environment do |t, args|
    include Redis::ArchiveRedis
    all_shards = Sharding.all_shards
    if args.shard
      runnable_shards = all_shards & args.shard.to_a # validate shard names provided as arguement
    else
      blacklist_archive_shards = $redis_tickets.perform_redis_op('smembers', 'blacklist_archive_shards')
      runnable_shards = all_shards - blacklist_archive_shards
    end

    runnable_shards.each do |shard_name|
      Sharding.run_on_shard(shard_name) do
        current_archive_shard = ActiveRecord::Base.current_shard_selection.shard.to_s + '_archive'
        account_ids = account_ids_in_shard(current_archive_shard)
        account_ids.each do |account_id|
          begin
            account = Account.find(account_id).make_current
            next if account.disable_archive_enabled?

            Archive::AccountTicketsWorker.perform_async(account_id: account_id, ticket_status: :closed)
          rescue Exception => e
            Rails.logger.debug "Error in Archive automation :: #{e.message}"
          end
        end
      end
    end
  end
end
