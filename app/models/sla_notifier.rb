class SlaNotifier < ActionMailer::Base
  
  def escalation(ticket, agent, params)
    subject       params[:subject]
    body          params[:email_body]
    recipients    agent.email
    from          ticket.account.default_friendly_email
    sent_on       Time.now    
    headers       "Reply-to" => "#{ticket.account.default_friendly_email}", "Auto-Submitted" => "auto-generated", "X-Auto-Response-Suppress" => "DR, RN, OOF, AutoReply"
    content_type  "text/html"
  end
  
end
