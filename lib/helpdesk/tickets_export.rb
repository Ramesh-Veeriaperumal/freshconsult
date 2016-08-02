class Helpdesk::TicketsExport 
  extend Resque::AroundPerform
  @queue = 'ticketsExportQueue'

  def self.perform(export_params)
  	#harcoding key here to avoid instance/class method conflict.
  	key = "PREMIUM_TICKET_EXPORT"
  	long_running_key = "LONG_RUNNING_TICKET_EXPORT"
  	if $redis_others.perform_redis_op("sismember", key, Account.current.id)
  		Resque.enqueue(Helpdesk::PremiumTicketsExport, export_params)
  	elsif $redis_others.perform_redis_op("sismember", long_running_key, Account.current.id)
  		Resque.enqueue(Helpdesk::LongRunningTicketsExport, export_params)
  	else
  		Export::Ticket.new(export_params).perform
  	end
  end
end