REDUCE_VALUE = 1000
namespace :populate do
  task :spam_watcher_limits => :environment do
    max_ticket_id = Helpdesk::Ticket.maximum(:id) - REDUCE_VALUE
    max_note_id = Helpdesk::Note.maximum(:id) - REDUCE_VALUE
    shards = Sharding.all_shards
      shards.each do |shard_name|
      $stats_redis.set("#{shard_name}:tickets_limit","#{max_ticket_id}")
      $stats_redis.set("#{shard_name}:notes_limit","#{max_note_id}")
    end
  end  
end


