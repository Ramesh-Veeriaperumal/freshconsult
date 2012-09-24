class Import::Zen::ZendeskTicketImport 
	extend Resque::Plugins::Retry
  @queue = 'zendeskTicketImport'

  @retry_limit = 3
  @retry_delay = 60*2

  def self.perform(ticket_xml , domain)
  	Import::Zen::TicketImport.new(ticket_xml ,domain)
  end
end