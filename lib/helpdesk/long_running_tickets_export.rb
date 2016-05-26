class Helpdesk::LongRunningTicketsExport 
  extend Resque::AroundPerform
  @queue = 'long_running_ticket_export'

  def self.perform(export_params)
  	Export::Ticket.new(export_params).perform
  end
end