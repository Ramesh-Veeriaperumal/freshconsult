class Helpdesk::PremiumTicketsExport 
  extend Resque::AroundPerform
  @queue = 'premium_ticket_export'

  def self.perform(export_params)
  	Helpdesk::TicketsExportWorker.new(export_params).perform
  end
end