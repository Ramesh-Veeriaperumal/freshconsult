class Tickets::BulkTicketReply < BaseWorker

  sidekiq_options :queue => :bulk_ticket_reply, :retry => 0, :failures => :exhausted

  def perform(args)
    begin
      args["account_id"] = Account.current.id
      performer = Helpdesk::BulkReplyTickets.new(args.symbolize_keys)
      performer.act
      performer.cleanup!
    rescue Exception => e
      NewRelic::Agent.notice_error(e,{:description => "Sidekiq Bulk reply error"})
      raise e
    ensure 
      begin
        Timeout::timeout(SpamConstants::SPAM_TIMEOUT) do
          key,value = args["spam_key"].split(":")
          $spam_watcher.perform_redis_op("del", key) if value == $spam_watcher.perform_redis_op("get", key)
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e,{:description => "error occured while deleting a bulk reply key"})
      end
    end
  end

end
