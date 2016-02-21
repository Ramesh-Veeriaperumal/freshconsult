class Workers::BulkReplyTickets
  extend Resque::AroundPerform 
  @queue = 'bulk_reply_tickets'

  def self.perform(params)
  	begin
	    performer = Helpdesk::BulkReplyTickets.new(params)
	    performer.act
	    performer.cleanup!
	  ensure 
	  	begin
		  	Timeout::timeout(SpamConstants::SPAM_TIMEOUT) do
		  		key,value = params[:spam_key].split(":")
		  		$spam_watcher.perform_redis_op("del", key) if value == $spam_watcher.perform_redis_op("get", key)
		  	end
	  	rescue Exception => e
	  		NewRelic::Agent.notice_error(e,{:description => "error occured while deleting a bulk reply key"})
	  	end
	  end
  end

end