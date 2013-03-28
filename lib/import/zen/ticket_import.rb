class Import::Zen::TicketImport 

  include Import::Zen::Ticket
  include Import::Zen::FlexiField

  def initialize(ticket_xml)
  	@current_account = Account.current
    return if @current_account.blank?
    disable_notification
    save_ticket ticket_xml
    enable_notification
  end


private

  def disable_notification        
     Thread.current["notifications_#{@current_account.id}"] = EmailNotification::DISABLE_NOTIFICATION  
     Thread.current["zenimport_#{@current_account.id}"] = true  
  end
  
  def enable_notification
    Thread.current["notifications_#{@current_account.id}"] = nil
    Thread.current["zenimport_#{@current_account.id}"] = false  
  end

end