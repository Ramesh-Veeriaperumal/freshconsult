module Slainit
  # This will initialize SLA scheduler which will be called in every 1 min 
  require 'rufus/scheduler'
  
  puts "Slainit"
  
  scheduler = Rufus::Scheduler.start_new

  scheduler.every '1m' do
    
  @overdue_tickets = Helpdesk::Ticket.find(:all, :conditions =>['due_by <=? AND isescalated=? AND status=?', Time.now.to_s(:db),false,1] )
    puts @overdue_tickets      
  @overdue_tickets.each do |ticket|
         puts "ticket with following id breaches sla" +ticket.id
         escalateto = Helpdesk::SlaDetail.find_by_priority(ticket.priority).escalateto
         email = User.find_by_id(escalateto).email
         #user_notifier(email) #This method should send an email          
         SlaNotifier.deliver_sla_escalation(ticket, email)        
         ticket.isescalated = true
         ticket.save
      
   end
  
   @froverdue_tickets = Helpdesk::Ticket.find(:all, :conditions =>['frDueBy <=? AND fr_escalated=? AND response_time= ?', Time.now.to_s(:db),false,nil] )
   puts @froverdue_tickets
   @froverdue_tickets.each do |fr_ticket|
         
         puts "ticket with following id breaches first response" +fr_ticket.id
         fr_escalateto = Helpdesk::SlaDetail.find_by_priority(fr_ticket.priority).escalateto
         fr_email = User.find_by_id(fr_escalateto).email
         #user_notifier(email) #This method should send an email          
         SlaNotifier.deliver_fr_sla_escalation(fr_ticket,fr_email)        
         fr_ticket.fr_escalated = true
         fr_ticket.save
      
   end
  
   end
   
end