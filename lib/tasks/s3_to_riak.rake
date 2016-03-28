
namespace :s3_to_riak do
  desc "Migrating the failed jobs from s3 to riak"
  task :ticket_creation_failed_request => :environment do |task|
    # failed ticket creation
    puts "failed ticket creation"
    while(true) do
      begin
        puts "inside creation"
        ticket = $redis_tickets.perform_redis_op("lpop", Redis::RedisKeys::RIAK_FAILED_TICKET_CREATION)
        break unless ticket
        account_id, ticket_id = ticket.split("/")
        ticket_body = {}
        ticket_body[:ticket_body] = Helpdesk::S3::Ticket::Body.get_from_s3(account_id, ticket_id)
        key = "#{account_id}/#{ticket_id}"
        value = ticket_body.to_json
        Helpdesk::Riak::Ticket::Body.store_in_riak(key,value)
      rescue Exception => e
        NewRelic::Agent.notice_error(e,{:description => "error occured while creating ticket from riak"})
        # exception caught incase of any failure
      end
    end
  end

  task :ticket_deletion_failed_request => :environment do |task|
    puts "failed ticket deletion"
    while(true) do
      begin
        puts "inside deletion"
        ticket = $redis_tickets.perform_redis_op("lpop", Redis::RedisKeys::RIAK_FAILED_TICKET_DELETION)
        break unless ticket
        $ticket_body.delete(ticket)
      rescue Exception => e
        NewRelic::Agent.notice_error(e,{:description => "error occured while deleting ticket from riak"})
        # exception caught incase of any failure
      end
    end
  end

  task :note_creation_failed_request => :environment do |task|
    puts "failed note creation"
    while(true) do
      begin
        puts "inside creation note"
        note = $redis_tickets.perform_redis_op("lpop", Redis::RedisKeys::RIAK_FAILED_NOTE_CREATION)
        break unless note
        account_id, note_id = note.split("/")
        note_body = {}
        note_body[:note_body] = Helpdesk::S3::Note::Body.get_from_s3(account_id, note_id)
        key = "#{account_id}/#{note_id}"
        value = note_body.to_json
        Helpdesk::Riak::Note::Body.store_in_riak(key,value)
      rescue Exception => e
        NewRelic::Agent.notice_error(e,{:description => "error occured while creating note from riak"})
        # exception caught incase of any failure
      end
    end
  end

  task :note_deletion_failed_request => :environment do |task|
    puts "failed note deletion"
  	while(true) do
      begin
        puts "inside deletion note"
        note = $redis_tickets.perform_redis_op("lpop", Redis::RedisKeys::RIAK_FAILED_NOTE_DELETION)
        break unless note
        $note_body.delete(note)
      rescue Exception => e
        NewRelic::Agent.notice_error(e,{:description => "error occured while deleting note from riak"})
        # exception caught incase of any failure
      end
    end
  end
end
