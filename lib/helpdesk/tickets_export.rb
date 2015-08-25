class Helpdesk::TicketsExport 
  extend Resque::AroundPerform
  @queue = 'ticketsExportQueue'

  def self.perform(export_params)
  	#harcoding key here to avoid instance/class method conflict.
  	key = "PREMIUM_TICKET_EXPORT"
  	if $redis_others.sismember(key, Account.current.id)
  		Resque.enqueue(Helpdesk::PremiumTicketsExport, export_params)
  	else
  		Helpdesk::TicketsExportWorker.new(export_params).perform
  	end
  end
end