class Tickets::Export::PremiumTicketsExport 
	include Sidekiq::Worker
	sidekiq_options :queue => :premium_ticket_export, :retry => 0, :backtrace => true, :failures => :exhausted

	def perform(export_params)
		Export::Ticket.new(export_params).perform
	end
end