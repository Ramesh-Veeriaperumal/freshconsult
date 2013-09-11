class Import::Zen::UserImport 

  include Import::Zen::User
  

  def initialize(user_xml)
  	@current_account = Account.current
    return if @current_account.blank?
    disable_notification
    save_user user_xml
  ensure
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