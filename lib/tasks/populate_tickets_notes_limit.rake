REDUCE_VALUE = 1000
namespace :populate do
  task :spam_watcher_limits => :environment do
  	shards = Sharding.all_shards
  	shards.each do |shard_name|
     shard_sym = shard_name.to_sym
     puts "shard_name is #{shard_name}"
     Sharding.run_on_shard(shard_name.to_sym) {
    	max_ticket_id = Helpdesk::Ticket.maximum(:id) - REDUCE_VALUE
	    max_note_id = Helpdesk::Note.maximum(:id) - REDUCE_VALUE
	    $redis_others.perform_redis_op("set", "#{shard_name}:tickets_limit","#{max_ticket_id}")
      $redis_others.perform_redis_op("set", "#{shard_name}:notes_limit","#{max_note_id}")
	  	}
    end     
  end  
end