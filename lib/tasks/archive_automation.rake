namespace :archive_automation do
  
  desc "This task archives all closed tickets with no activities in the last n days"
  task :archive_automation_tickets => :environment do
    shards = $redis_tickets.perform_redis_op("smembers","archive_automation_shards")
    return if shards.blank?
    shards.each do |shard_name|
      Sharding.run_on_shard(shard_name) do
        current_archive_shard = ActiveRecord::Base.current_shard_selection.shard.to_s + "_archive"
        account_ids = $redis_tickets.perform_redis_op("lrange",current_archive_shard,0,-1)
        account_ids.each do |account_id|
          # puts account_id
          account = Account.find(account_id).make_current
          next if account.launched?(:disable_archive)
          Archive::TicketsSplitter.new.perform({ "account_id" => account_id, "ticket_status" => "closed" })
        end
      end
    end
  end
end
