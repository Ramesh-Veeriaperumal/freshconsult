require 'mms2r'

class Helpdesk::TicketNotifier < ActionMailer::Base

  def self.notify_by_email(notification_type, ticket)
    e_notification = ticket.account.email_notifications.find_by_notification_type(notification_type)
    if e_notification.agent_notification
      a_template = Liquid::Template.parse(e_notification.agent_template)
      deliver_internal_email(ticket, 
              (notification_type == EmailNotification::TICKET_ASSIGNED_TO_GROUP) ? ticket.group.agent_emails : ticket.responder.email, 
              a_template.render('ticket' => ticket))
    end
    
    if e_notification.requester_notification
      r_template = Liquid::Template.parse(e_notification.requester_template)
      deliver_email_to_requester(ticket, r_template.render('ticket' => ticket, 'helpdesk_name' => ticket.account.helpdesk_name))
    end
  end

  def reply(ticket, note)
    body(:ticket => ticket, :note => note, :host => ticket.account.full_domain)
    reply_to_ticket(ticket)
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
  
  def reply_to_ticket(ticket)
    #subject       Helpdesk::EMAIL[:reply_subject]  + " #{ticket.encode_display_id}"
    subject       "Re: #{ticket.subject}"
    recipients    ticket.requester.email
    do_send(ticket)
  end
  
  def do_send(ticket)
    from_to_use = ticket.reply_email
    from          from_to_use
    headers       "Reply-to" => "#{from_to_use}"
    sent_on       Time.now
    content_type  "text/plain"
  end
  
  def receive(email)
    retried = false
    begin
      process_incoming(email)
    rescue => e #ActiveRecord::StatementInvalid
      puts e.inspect
      puts e.backtrace
      #ActiveRecord::Base.connection.reconnect!
      #unless retried
        #retried = true
        #retry
      #end
      #raise
    end
  end

protected

  def process_incoming(email)
    token = Helpdesk::Ticket.extract_id_token(email.subject)
    ticket = Helpdesk::Ticket.find_by_id_token(token) if token

    media = MMS2R::Media.new(email)

    # Try to detect bounces and route them to the correct ticket.
    if !ticket && (media.body =~ /From: #{ticket.account.default_email}/)
      s = media.body.match(/^Subject: (.*)/)
      subject  = s && s[1]

      if subject
        token = Helpdesk::Ticket.extract_id_token(subject)
        ticket = Helpdesk::Ticket.find_by_id_token(token) if token
      end
    end

    if ticket
      if ticket.status <= 0
        ticket.update_attribute(:status, Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:open])
        ticket.create_status_note("Ticket was reopened due to customer email.")
      end
      add_email_to_ticket(ticket, email, media)
    else
      ticket = create_ticket(email, media)
      add_email_to_ticket(ticket, email, media)
    end
  end

  def create_ticket(email, media)
    ticket = Helpdesk::Ticket.new(
      :description => media.subject.empty? ? media.body : media.subject,
      :email => email.reply_to ? email.reply_to[0] : email.from[0],
      :name => email.friendly_from,
      :status => Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:open],
      :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:email]
    )

    if User.column_names.include?("email")
      u = User.find_by_email(email.from[0])
      if(u)
        ticket.requester_id =  u.id
        ticket.name = u.name if u.respond_to?(:name)
      end
    end

    if ticket.save
      return ticket
    end
  end

  def add_email_to_ticket(ticket, email, media)
      note = ticket.notes.build(
        :private => false,
        :incoming => true,
        :body => media.body,
        :source => 0
      )
      if note.save
        (email.attachments || []).each do |attachment|
          note.attachments.create(:content => attachment)
        end
      end
  end

end
