class Import::Zen::ZendeskTicketImport 
  @queue = 'zendeskTicketImport'

  def self.perform(ticket_xml , domain)
  	Import::Zen::TicketImport.new(ticket_xml ,domain)
  end
end