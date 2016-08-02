class Tickets::Export::TicketsExport < BaseWorker
	include Sidekiq::Worker
	sidekiq_options :queue => :tickets_export_queue, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(export_params)
  	Export::Ticket.new(export_params).perform
  end
end