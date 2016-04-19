class Tickets::Export::PremiumTicketsExport 
	include Sidekiq::Worker
	sidekiq_options :queue => :premium_ticket_export, :retry => 0, :backtrace => true, :failures => :exhausted

	def perform(export_params)
		Helpdesk::TicketsExportWorker.new(export_params).perform
	end
end