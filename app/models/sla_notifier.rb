class SlaNotifier < ActionMailer::Base
  

  def sla_escalation(ticket, email)
    subject       'SlaNotifier#sla_escalation'
    recipients    email
    from          ticket.account.default_email
    sent_on       Time.now    
    body          :ticket => ticket, :host => ticket.account.host
    headers       "Reply-to" => "#{ticket.account.default_email}"
    content_type  "text/plain"
  end
  
  def fr_sla_escalation(ticket, email)
    subject       'SlaNotifier#first_response_sla_escalation'
    recipients    email
    from          ticket.account.default_email
    sent_on       Time.now    
    body          :ticket => ticket, :host => ticket.account.host
    headers       "Reply-to" => "#{ticket.account.default_email}"
    content_type  "text/plain"
  end

end
