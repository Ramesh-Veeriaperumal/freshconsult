module Slainit
  # This will initialize SLA scheduler which will be called in every 1 min 
  require 'rufus/scheduler'
  
  puts "Slainit"
  
  scheduler = Rufus::Scheduler.start_new

  scheduler.every '1m' do
    
  @overdue_tickets = Helpdesk::Ticket.find(:all, :conditions =>['due_by <=?', Time.now.to_s(:db)] )
           
  @overdue_tickets.each do |ticket|
         
         escalateto = Helpdesk::SlaDetail.find_by_priority(ticket.priority).escalateto
         #email = User.find_by_id(escalateto).email
         #user_notifier(email) #This method should send an email          
         UserNotifier.deliver_notifysla_escalation(User.find_by_id(escalateto), ticket)        
         ticket.isescalated = true
         ticket.save
      
   end
  
   @froverdue_tickets = Helpdesk::Ticket.find(:all, :conditions =>['frDueBy <=?', Time.now.to_s(:db)] )
   
   @froverdue_tickets.each do |frticket|
         
         frescalateto = Helpdesk::SlaDetail.find_by_priority(frticket.priority).escalateto
         #email = User.find_by_id(escalateto).email
         #user_notifier(email) #This method should send an email          
         UserNotifier.deliver_notifysla_escalation(User.find_by_id(frescalateto), frticket)        
         frticket.isescalated = true
         frticket.save
      
   end
  
   end
   
end