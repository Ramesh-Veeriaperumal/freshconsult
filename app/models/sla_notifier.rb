class SlaNotifier < ActionMailer::Base
  

  def sla_escalation(ticket, agent)
    subject       subject_for_resolution(ticket)
    recipients    agent.email
    from          ticket.account.default_email
    sent_on       Time.now    
    body          :ticket => ticket, :host => ticket.account.host , :name =>agent.name
    headers       "Reply-to" => "#{ticket.account.default_email}"
    content_type  "text/plain"
  end
  
  def fr_sla_escalation(ticket, agent)
    subject       subject_for_response(ticket)
    recipients    agent.email
    from          ticket.account.default_email
    sent_on       Time.now    
    body          :ticket => ticket, :host => ticket.account.host , :name =>agent.name
    headers       "Reply-to" => "#{ticket.account.default_email}"
    content_type  "text/plain"
  end
  
   def subject_for_resolution(ticket)
    "SLA Violation - Resolution #{ticket.encode_display_id} #{ticket.subject}"
  end
  
   def subject_for_response(ticket)
    "SLA Violation - Response #{ticket.encode_display_id} #{ticket.subject}"
  end

end
