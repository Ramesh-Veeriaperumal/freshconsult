# usage rake archive_tickets:archive_closed_tickets
# This checks for feature for intial few days, till everything is working properly
namespace :archive_tickets do
  
  desc "This task archives all closed tickets with no activities in the last n days"
  task :archive_closed_tickets => :environment do
    Sharding.run_on_all_slaves do
      current_archive_shard = ActiveRecord::Base.current_shard_selection.shard.to_s + "_archive"
      account_ids = $redis_tickets.perform_redis_op("lrange",current_archive_shard,0,-1)
      account_ids.each do |account_id|
        # puts account_id
        account = Account.find(account_id).make_current
        Archive::TicketsSplitter.perform_async({ :account_id => account_id, :ticket_status => :closed })
      end
    end
  end
end
