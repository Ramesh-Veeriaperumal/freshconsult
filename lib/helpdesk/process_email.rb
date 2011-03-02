class Helpdesk::ProcessEmail < Struct.new(:params)
  
  def perform
    from_email = parse_email params[:from]
    to_email = parse_to_email
    account = Account.find_by_full_domain(to_email[:domain])
    if !account.nil?
      display_id = Helpdesk::Ticket.extract_id_token(params[:subject])
      ticket = Helpdesk::Ticket.find_by_account_id_and_display_id(account.id, display_id) if display_id
      
      if ticket
        comment = add_email_to_ticket(ticket, from_email, params[:text])
        
        if comment.user.customer?
          unless ticket.active?
            ticket.update_attribute(:status, Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:open])
            notification_type = EmailNotification::TICKET_REOPENED
          end
          
          Helpdesk::TicketNotifier.notify_by_email((notification_type ||= EmailNotification::REPLIED_BY_REQUESTER), 
                                                    ticket, comment) if ticket.responder
        else
          Helpdesk::TicketNotifier.notify_by_email(EmailNotification::COMMENTED_BY_AGENT, ticket, comment)
        end
      else
        ticket = create_ticket(account, from_email, to_email)
      end
    end
  end
  
  private
    def parse_email(email)
      if email =~ /(.+) <(.+?)>/
        name = $1
        email = $2
      end
      
      name ||= ""
      domain = (/@(.+)/).match(email).to_a[1]
      
      {:name => name, :email => email, :domain => domain}
    end
    
    def parse_to_email
      envelope = params[:envelope]
      unless envelope.nil?
        envelope_to = (ActiveSupport::JSON.decode envelope)['to']
        return parse_email envelope_to.first unless (envelope_to.nil? || envelope_to.empty?)
      end
      
      parse_email params[:to]
    end
    
    def create_ticket(account, from_email, to_email)
      ticket = Helpdesk::Ticket.new(
        :account_id => account.id,
        :subject => params[:subject],
        :description => params[:text],
        :email => from_email[:email],
        :to_email => to_email[:email],
        :email_config => account.email_configs.find_by_to_email(to_email[:email]),
        :status => Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:open],
        :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:email]
      )
 
      ticket.save
      create_attachments(ticket, ticket)
      ticket.create_activity(ticket.requester, "{{user_path}} submitted a new ticket {{notable_path}}", {}, 
                                   "{{user_path}} submitted the ticket")
      ticket
    end

    def add_email_to_ticket(ticket, from_email, mesg)
      user = get_user(ticket, from_email[:email])
      note = ticket.notes.build(
          :private => false,
          :incoming => true,
          :body => mesg,
          :source => 0, #?!?! use SOURCE_KEYS_BY_TOKEN - by Shan
          :user => user, #by Shan temp
          :account_id => ticket.account_id
      )
      
      create_attachments(ticket, note) if note.save 
      
      ticket.create_activity(note.user, "{{user_path}} sent an {{email_response_path}} to the ticket {{notable_path}}", 
                    {'eval_args' => {'email_response_path' => ['email_response_path', {
                                                        'ticket_id' => ticket.display_id, 
                                                        'comment_id' => note.id}]}},
                     "{{user_path}} sent an {{email_response_path}}")
      
      note
    end
    
    def get_user(ticket, email)
      user = ticket.account.users.find_by_email(email)
      unless user
        user = ticket.account.contacts.new
        user.signup!({:user => {:email => email, :name => '', :user_role => User::USER_ROLES_KEYS_BY_TOKEN[:customer]}})
      end
      
      user
    end

    def create_attachments(ticket, item)
      Integer(params[:attachments]).times do |i|
        item.attachments.create(:content => params["attachment#{i+1}"], :account_id => ticket.account_id)
      end
    end
  
end
