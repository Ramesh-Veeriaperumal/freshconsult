class Helpdesk::TicketNotifier < ActionMailer::Base

  def self.notify_by_email(notification_type, ticket, comment = nil)
    e_notification = ticket.account.email_notifications.find_by_notification_type(notification_type)
    if e_notification.agent_notification
      a_template = Liquid::Template.parse(e_notification.agent_template)
      deliver_internal_email(ticket, 
              (notification_type == EmailNotification::TICKET_ASSIGNED_TO_GROUP) ? ticket.group.agent_emails : ticket.responder.email, 
              a_template.render('ticket' => ticket, 'comment' => comment))
    end
    
    if e_notification.requester_notification
      r_template = Liquid::Template.parse(e_notification.requester_template)
      deliver_email_to_requester(ticket, r_template.render('ticket' => ticket, 'helpdesk_name' => ticket.account.helpdesk_name, 
                                                           'comment' => comment))
    end
  end

  def reply(ticket, note , reply_email)
    body(:ticket => ticket, :note => note, :host => ticket.account.full_domain)
    content_type    "multipart/alternative"

    note.attachments.each do |a|
      attachment  :content_type => a.content_content_type, 
                  :body => File.read(a.content.to_file.path), 
                  :filename => a.content_file_name
    end   
    
    reply_to_ticket(ticket, reply_email)
  end
  
  def email_to_requester(ticket, content)
    body(content)
    reply_to_ticket(ticket)
  end
  
  def internal_email(ticket, receips, content)
    subject       "Notice for the ticket #{ticket.encode_display_id}"
    recipients    receips
    body(content)
    do_send(ticket)
  end
  
  def reply_to_ticket(ticket , reply_email= nil)
    #subject       Helpdesk::EMAIL[:reply_subject]  + " #{ticket.encode_display_id}"
    subject       "Re: #{ticket.subject} #{ticket.encode_display_id}"
    recipients    ticket.requester.email
    do_send(ticket , reply_email)
  end
  
  def do_send(ticket, reply_email= nil)
    from_to_use = reply_email ||ticket.reply_email
    from          from_to_use
    headers       "Reply-to" => "#{from_to_use}"
    sent_on       Time.now
    content_type  "text/plain"
  end
end
