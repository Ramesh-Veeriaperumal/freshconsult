class EmailController < ApplicationController
  skip_before_filter :verify_authenticity_token
  
  def new
  end

  def create
    from_email = parse_email params[:from]
    to_email = parse_email params[:to]
    account = Account.find_by_full_domain(to_email[:domain])
    if !account.nil?
      display_id = Helpdesk::Ticket.extract_id_token(params[:subject])
      ticket = Helpdesk::Ticket.find_by_account_id_and_display_id(account.id, display_id) if display_id
      
      if ticket
        add_email_to_ticket(ticket, params[:text])
      else
        ticket = create_ticket(account, from_email, to_email)
        add_email_to_ticket(ticket)
        Helpdesk::TicketNotifier.deliver_autoreply(ticket) if !ticket.spam
      end
    end
  end
  
  private
    def parse_email email
      if email =~ /(.+) <(.+?)>/
        name = $1
        email = $2
      end
      
      name ||= ""
      domain = (/@(.+)/).match(email).to_a[1]
      
      {:name => name, :email => email, :domain => domain}
    end
    
    def create_ticket(account, from_email, to_email)
      ticket = Helpdesk::Ticket.new(
        :account_id => account.id,
        :subject => params[:subject],
        :description => params[:text],
        :email => from_email[:email],
        #:name => email.friendly_from,
        :status => Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:open],
        :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:email]
      )
 
      ticket.save
      ticket
    end

    def add_email_to_ticket(ticket, mesg=nil)
        note = ticket.notes.build(
          :private => false,
          :incoming => true,
          :body => mesg.nil? ? ticket.description : mesg,
          :source => 0,
          :account_id => ticket.account_id
        )
        if note.save
          Integer(params[:attachments]).times do |i|
            #logger.debug("attachment #{i}")
            note.attachments.create(:content => params["attachment#{i+1}"], :account_id => ticket.account_id)
          end
        end
    end
end
