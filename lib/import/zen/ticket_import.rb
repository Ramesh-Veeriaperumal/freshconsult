class Import::Zen::TicketImport 

  include Import::Zen::Ticket
  include Import::Zen::FlexiField

  def initialize(ticket_xml , domain)
  	@current_account = Account.find_by_full_domain(domain)
  	@current_account.make_current    
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