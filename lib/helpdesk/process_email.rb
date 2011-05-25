class Helpdesk::ProcessEmail < Struct.new(:params)
  
  def perform
    from_email = parse_email params[:from]
    to_email = parse_to_email
    account = Account.find_by_full_domain(to_email[:domain])
    if !account.nil?
      #Charset Encoding starts
      charsets = params[:charsets]
      text_retrv = params[:text].nil? ? 'html' : 'text'
      charset_encoding = (ActiveSupport::JSON.decode charsets)[text_retrv]
      if  !charset_encoding.nil? and  !(["utf-8","utf8"].include?(charset_encoding.downcase))
        params[:text] = Iconv.new('utf-8//IGNORE', charset_encoding).iconv(params[text_retrv.to_sym]) 
      end
      #Charset Encoding ends
      display_id = Helpdesk::Ticket.extract_id_token(params[:subject])
      ticket = Helpdesk::Ticket.find_by_account_id_and_display_id(account.id, display_id) if display_id
      if ticket
        return if(from_email[:email] == ticket.reply_email) #Premature handling for email looping..
        add_email_to_ticket(ticket, from_email, params[:text])
      else
        create_ticket(account, from_email, to_email)
      end
    end
  end
  
  private
    def parse_email(email)
      if email =~ /(.+) <(.+?)>/
        name = $1
        email = $2
      elsif email =~ /<(.+?)>/
        email = $1
      else email =~ /(\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b)/
        email = $1
      end
      
      name ||= ""
      domain = (/@(.+)/).match(email).to_a[1]
      
      {:name => name, :email => email, :domain => domain}
    end
    
    def orig_email_from_text #To process mails fwd'ed from agents
      if params[:text].gsub("\r\n", "\n") =~ /^\s*From:\s*(.*)\s+<(.*)>$/
        { :name => $1, :email => $2 }
      end
    end
    
    def parse_to_email
      envelope = params[:envelope]
      unless envelope.nil?
        envelope_to = (ActiveSupport::JSON.decode envelope)['to']
        return parse_email envelope_to.first unless (envelope_to.nil? || envelope_to.empty?)
      end
      
      parse_email params[:to]
    end
    
    def parse_cc_email
      cc_array = []
      unless params[:cc].nil?
        cc_array = params[:cc].split(',').collect! {|n| (parse_email n)[:email]}
      end
      return cc_array.uniq
    end
    
    def create_ticket(account, from_email, to_email)
      user = get_user(account, from_email)
      unless user.customer?
        e_email = orig_email_from_text
        user = get_user(account, e_email) unless e_email.nil?
      end

      ticket = Helpdesk::Ticket.new(
        :account_id => account.id,
        :subject => params[:subject],
        :description => params[:text],
        #:email => from_email[:email],
        #:name => from_email[:name],
        :requester => user,
        :to_email => to_email[:email],
        :cc_email => parse_cc_email,
        :email_config => account.email_configs.find_by_to_email(to_email[:email]),
        :status => Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:open],
        :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:email],
        :ticket_type =>Helpdesk::Ticket::TYPE_KEYS_BY_TOKEN[:how_to]
      )
      ticket = check_for_chat_scources(ticket,from_email)
      ticket.group_id = ticket.email_config.group_id unless ticket.email_config.nil?
      begin
        ticket.save!
        create_attachments(ticket, ticket)
        ticket.create_activity(ticket.requester, "{{user_path}} submitted a new ticket {{notable_path}}", {}, 
                                   "{{user_path}} submitted the ticket")
        ticket
      rescue ActiveRecord::RecordInvalid => e
        FreshdeskErrorsMailer.deliver_error_email(ticket,params,e)
      end
    end
  
    def check_for_chat_scources(ticket,from_email)
      ticket.source = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:chat] if Helpdesk::Ticket::CHAT_SOURCES.has_value?(from_email[:domain])
      if from_email[:domain] == Helpdesk::Ticket::CHAT_SOURCES[:snapengage]
        emailreg = Regexp.new(/\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b/)
        chat_email =  params[:subject].scan(emailreg).uniq[0]
        ticket.email = chat_email unless chat_email.blank? && (chat_email == "unknown@example.com")
      end
      ticket
    end

    def add_email_to_ticket(ticket, from_email, mesg)
      user = get_user(ticket.account, from_email)
      note = ticket.notes.build(
          :private => false,
          :incoming => true,
          :body => mesg,
          :source => 0, #?!?! use SOURCE_KEYS_BY_TOKEN - by Shan
          :user => user, #by Shan temp
          :account_id => ticket.account_id
      )
      
      create_attachments(ticket, note) if note.save 
      note
    end
    
    def get_user(account, from_email)
      user = account.users.find_by_email(from_email[:email])
      unless user
        user = account.contacts.new
        user.signup!({:user => {:email => from_email[:email], :name => from_email[:name], 
          :user_role => User::USER_ROLES_KEYS_BY_TOKEN[:customer]}})
      end
      user
    end

    def create_attachments(ticket, item)
      Integer(params[:attachments]).times do |i|
        item.attachments.create(:content => params["attachment#{i+1}"], :account_id => ticket.account_id)
      end
    end
  
end
