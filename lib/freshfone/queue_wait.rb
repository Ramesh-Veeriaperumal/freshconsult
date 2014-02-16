class Freshfone::QueueWait
	extend Resque::AroundPerform
	
	@queue = "freshfone_queue_wait"
	
	def self.perform(args)
		begin
			@account = Account.current
			queue_sid = args[:queue_sid]; call_sid = args[:call_sid]
			host = @account.url_protocol + "://" + @account.host + "/freshfone/queue/trigger_non_availability"
			queued_member = @account.freshfone_subaccount.queues.get(queue_sid).members.get(call_sid)
   		queued_member.dequeue(host)
		rescue Exception => e
			puts "Error in processing queued freshfone calls :: \n#{e.message}\n#{e.backtrace.join("\n\t")}"
			NewRelic::Agent.notice_error(e)
		end
	end
end