class Helpdesk::TicketsExport 
  extend Resque::AroundPerform
  @queue = 'ticketsExportQueue'

  def self.perform(export_params)
    Helpdesk::TicketsExportWorker.new(export_params).perform
  end
end