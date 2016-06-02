class Tickets::Export::LongRunningTicketsExport 
	include Sidekiq::Worker
	sidekiq_options :queue => :long_running_ticket_export, :retry => 0, :backtrace => true, :failures => :exhausted

	def perform(export_params)
		Export::Ticket.new(export_params).perform
	end
end