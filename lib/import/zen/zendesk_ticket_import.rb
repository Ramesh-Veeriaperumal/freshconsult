class Import::Zen::ZendeskTicketImport 
  extend Resque::AroundPerform

  @queue = "zendeskTicketImport"

  def self.perform(args)
  	Import::Zen::TicketImport.new(args[:ticket_xml])
  end
end