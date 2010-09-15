require 'mms2r'

class Helpdesk::TicketNotifier < ActionMailer::Base


  def reply(ticket, note)
    body(:ticket => ticket, :note => note, :host => Helpdesk::HOST[RAILS_ENV.to_sym])
    reply_to_ticket(ticket)
  end

  def autoreply(ticket)
    body(:ticket => ticket, :host => Helpdesk::HOST[RAILS_ENV.to_sym])
    reply_to_ticket(ticket)
  end
  

  def receive(email)
    puts "Inside RECEIVE MAIL"
    retried = false
    begin
      puts "Inside RECEIVE MAIL BEGIN"
      process_incoming(email)
      puts "Inside RECEIVE MAIL PROCESS END"
    rescue => e #ActiveRecord::StatementInvalid
      puts "Inside RECEIVE MAIL RESCUE"
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
    if !ticket && (media.body =~ /From: #{Helpdesk::EMAIL[:from]}/)
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
      Helpdesk::TicketNotifier.deliver_autoreply(ticket) if ticket && !ticket.spam
    end
  end

  def reply_to_ticket(ticket)
    subject       Helpdesk::EMAIL[:reply_subject]  + " #{ticket.encode_id_token}"
    recipients    ticket.email
    from          Helpdesk::EMAIL[:from]
    headers       "Reply-to" => "#{Helpdesk::EMAIL[:from]}"
    sent_on       Time.now
    content_type  "text/plain"
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
