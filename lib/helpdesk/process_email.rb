class Helpdesk::ProcessEmail < Struct.new(:params)
 
  include EmailCommands
  
  EMAIL_REGEX = /(\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b)/
  
  def perform
    from_email = parse_from_email
    to_email = parse_to_email
    account = Account.find_by_full_domain(to_email[:domain])
    if !account.nil? and account.active?
      encode_stuffs
      kbase_email = account.kbase_email
      if (to_email[:email] != kbase_email) || (get_envelope_to.size > 1)
        display_id = Helpdesk::Ticket.extract_id_token(params[:subject], account.email_commands_setting.ticket_id_delimiter)
        ticket = Helpdesk::Ticket.find_by_account_id_and_display_id(account.id, display_id) if display_id
        if ticket
          return if(from_email[:email] == ticket.reply_email) #Premature handling for email looping..
          add_email_to_ticket(ticket, from_email )
        else
          create_ticket(account, from_email, to_email)
        end
      end
      
      begin
        if ((to_email[:email] == kbase_email) || (parse_cc_email && parse_cc_email.include?(kbase_email)))
          create_article(account, from_email, to_email)
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
    end
  end
  
  def create_article(account, from_email, to_email)

    article_params = {}

    email_config = account.email_configs.find_by_to_email(to_email[:email])
    user = get_user(account, from_email,email_config)
    
    article_params[:title] = params[:subject].gsub(Regexp.new("\\[#{account.email_commands_setting.ticket_id_delimiter}([0-9]*)\\]"),"")
    article_params[:description] = Helpdesk::HTMLSanitizer.clean(params[:html]) || params[:text]
    article_params[:user] = user.id
    article_params[:account] = account.id
    article_params[:content_ids] = params["content-ids"].nil? ? {} : get_content_ids

    attachments = {}
    
    Integer(params[:attachments]).times do |i|
      attachments["attachment#{i+1}"] = params["attachment#{i+1}"]
    end
      
    article_params[:attachments] = attachments
    
    Helpdesk::KbaseArticles.create_article_from_email(article_params)
  end
  
  private
    def encode_stuffs
      charsets = params[:charsets].blank? ? {} : ActiveSupport::JSON.decode(params[:charsets])
      [ :html, :text ].each do |t_format|
        unless params[t_format].nil?
          charset_encoding = charsets[t_format.to_s] 
          if !charset_encoding.nil? and !(["utf-8","utf8"].include?(charset_encoding.downcase))
            begin
              params[t_format] = Iconv.new('utf-8//IGNORE', charset_encoding).iconv(params[t_format])
            rescue
              #Do nothing here Need to add rescue code kiran
            end
          end
        end
      end
    end
    
    def parse_email(email_text)
      
      if email_text =~ /(.+) <(.+?)>/
        name = $1
        email = $2
      elsif email_text =~ /<(.+?)>/
        email = $1
      end
      
      if((email && !(email =~ EMAIL_REGEX) && (email_text =~ EMAIL_REGEX)) || (email_text =~ EMAIL_REGEX))
        email = $1  
      end


      name ||= ""
      domain = (/@(.+)/).match(email).to_a[1]
      
      {:name => name, :email => email, :domain => domain}
    end
    
    def orig_email_from_text #To process mails fwd'ed from agents
      content = params[:text] || Helpdesk::HTMLSanitizer.clean(params[:html] )
      if (content && (content.gsub("\r\n", "\n") =~ /^>*\s*From:\s*(.*)\s+<(.*)>$/ or 
                            content.gsub("\r\n", "\n") =~ /^\s*From:\s(.*)\s+\[mailto:(.*)\]/ or  
                            content.gsub("\r\n", "\n") =~ /^>>>+\s(.*)\s+<(.*)>$/))
        name = $1
        email = $2
        if email =~ EMAIL_REGEX
          { :name => name, :email => $1 }
        end
      end
    end
    
    def parse_orginal_to
      original_to = parse_email params[:to]            
      original_to_email =  original_to[:name].blank? ? original_to[:email] : "#{original_to[:name]} <#{original_to[:email]}>"      
    end
    
    def parse_to_email
      envelope = params[:envelope]
      unless envelope.nil?
        envelope_to = (ActiveSupport::JSON.decode envelope)['to']
        return parse_email envelope_to.first unless (envelope_to.nil? || envelope_to.empty?)
      end
      
      parse_email params[:to]
    end
    
    def parse_from_email
      f_email = parse_email(params[:from])
      return f_email unless(f_email[:email].blank? || f_email[:email] =~ /(noreply)|(no-reply)/i)
      
      headers = params[:headers]
      if(!headers.nil? && headers =~ /Reply-to:(.+)$/i)
        rt_email = parse_email($1)
        return rt_email unless rt_email[:email].blank?
      end
      
      f_email
    end
    
    def parse_cc_email
      cc_array = []
      unless params[:cc].nil?
        cc_array = params[:cc].split(',').collect! {|n| (parse_email n)[:email]}
      end
      return cc_array.uniq
    end
    
    def create_ticket(account, from_email, to_email)
      email_config = account.email_configs.find_by_to_email(to_email[:email])
      user = get_user(account, from_email,email_config)
      return if user.blocked? #Mails are dropped if the user is blocked
      unless user.customer?
        e_email = orig_email_from_text
        user = get_user(account, e_email , email_config) unless e_email.nil?
      end
     
      ticket = Helpdesk::Ticket.new(
        :account_id => account.id,
        :subject => params[:subject],
        :description => params[:text],
        :description_html => Helpdesk::HTMLSanitizer.clean(params[:html]),
        #:email => from_email[:email],
        #:name => from_email[:name],
        :requester => user,
        :to_email => parse_orginal_to,
        :cc_email => parse_cc_email,
        :email_config => email_config,
        :status => Helpdesk::Ticket::STATUS_KEYS_BY_TOKEN[:open],
        :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:email]
        #:ticket_type =>Helpdesk::Ticket::TYPE_KEYS_BY_TOKEN[:how_to]
      )
      ticket = check_for_chat_scources(ticket,from_email)
      ticket = check_for_spam(ticket)
      #ticket = check_for_auto_responders(ticket)
      
      process_email_commands(ticket, user, email_config) if user.agent?

      email_cmds_regex = get_email_cmd_regex(account)
      ticket.description = ticket.description.gsub(email_cmds_regex, "") if(!ticket.description.blank? && email_cmds_regex)
      ticket.description_html = ticket.description_html.gsub(email_cmds_regex, "") if(!ticket.description_html.blank? && email_cmds_regex)

      begin
        ticket.save!
        create_attachments(ticket, ticket)
        ticket
      rescue ActiveRecord::RecordInvalid => e
        FreshdeskErrorsMailer.deliver_error_email(ticket,params,e)
      end
    end
    
    def check_for_spam(ticket)
      ticket.spam = true if ticket.requester.deleted?
      ticket  
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
    
    def check_for_auto_responders(ticket)
      headers = params[:headers]
      if(!headers.blank? && ((headers =~ /Precedence:(\s)*[bulk|junk]/i) || (headers =~ /Auto-Submitted:(\s)*auto-*/i) || (headers =~ /Reply-To:(\s)*<>/i) || (headers =~ /Return-Path:(\s)*<>/i)))
        ticket.spam = true
      end
      ticket  
    end

    def add_email_to_ticket(ticket, from_email)
      user = get_user(ticket.account, from_email, ticket.email_config)
      return if user.blocked? #Mails are dropped if the user is blocked
      if can_be_added_to_ticket?(ticket,user)
        note = ticket.notes.build(
          :private => false,
          :incoming => true,
          :body => show_quoted_text(params[:text],ticket.reply_email),
          :body_html => show_quoted_text(Helpdesk::HTMLSanitizer.clean(params[:html] ), ticket.reply_email),
          :source => 0, #?!?! use SOURCE_KEYS_BY_TOKEN - by Shan
          :user => user, #by Shan temp
          :account_id => ticket.account_id
        )
        note.source = Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"] unless user.customer?
        process_email_commands(ticket, user, ticket.email_config) if user.agent?
        email_cmds_regex = get_email_cmd_regex(ticket.account)
        note.body = show_quoted_text(params[:text].gsub(email_cmds_regex, "") ,ticket.reply_email) if(!params[:text].blank? && email_cmds_regex)
        note.body_html = show_quoted_text(Helpdesk::HTMLSanitizer.clean(params[:html].gsub(email_cmds_regex, "")), ticket.reply_email) if(!params[:html].blank? && email_cmds_regex)
        ticket.save
      else
        return create_ticket(ticket.account, from_email, parse_to_email)
      end
      create_attachments(ticket, note) if note.save 
      note
    end
    
    def can_be_added_to_ticket?(ticket,user)
      !user.customer? or
      (ticket.requester.email and ticket.requester.email.include?(user.email)) or 
      (ticket.included_in_cc?(user.email)) or
      belong_to_same_company?(ticket,user)
    end
    
    def belong_to_same_company?(ticket,user)
      user.customer_id and (user.customer_id == ticket.requester.customer_id)
    end
    
    def get_user(account, from_email, email_config)
      portal = email_config ? email_config.portal : account.main_portal
      user = account.all_users.find_by_email(from_email[:email])
      unless user
        user = account.contacts.new
        user.signup!({:user => {:email => from_email[:email], :name => from_email[:name], 
          :user_role => User::USER_ROLES_KEYS_BY_TOKEN[:customer]}},portal)
      end
      user.make_current
      user
    end

    def create_attachments(ticket, item)
      temp_body_html = String.new(item.body_html)
      content_ids = params["content-ids"].nil? ? {} : get_content_ids 
     
      Integer(params[:attachments]).times do |i|
        created_attachment = item.attachments.create(:content => params["attachment#{i+1}"], :account_id => ticket.account_id)
        temp_body_html = replace_content_id(temp_body_html, content_ids["attachment#{i+1}"], created_attachment)
      end

      unless content_ids.blank?
        item.update_attributes!(:body_html => temp_body_html)
      end
    end
    
    def replace_content_id(bodyHTML, content_id, created_attachment)
        bodyHTML.sub!("cid:#{content_id}",created_attachment.content.url)  unless content_id.nil?
        bodyHTML
    end
  
    def get_content_ids
        content_ids = {}
        split_content_ids = params["content-ids"].tr("{}\\\"","").split(",")   
        split_content_ids.each do |content_id|
          split_content_id = content_id.split(":")
          content_ids[split_content_id[1]] = split_content_id[0]
        end
        content_ids  
    end
  
  def show_quoted_text(text, address)
    
    return text if text.blank?
    
    regex_arr = [
      Regexp.new("From:\s*" + Regexp.escape(address), Regexp::IGNORECASE),
      Regexp.new("<" + Regexp.escape(address) + ">", Regexp::IGNORECASE),
      Regexp.new(Regexp.escape(address) + "\s+wrote:", Regexp::IGNORECASE),   
      Regexp.new("\\n.*.\d.*." + Regexp.escape(address) ),
      Regexp.new("<div>\n<br>On.*?wrote:"),
      Regexp.new("On.*?wrote:"),
      Regexp.new("-+original\s+message-+\s*", Regexp::IGNORECASE),
      Regexp.new("from:\s*", Regexp::IGNORECASE)
    ]
    tl = text.length

    #calculates the matching regex closest to top of page
    index = regex_arr.inject(tl) do |min, regex|
        (text.index(regex) or tl) < min ? (text.index(regex) or tl) : min
    end
    
    original_msg = text[0, index]
    old_msg = text[index,text.size]
   
    unless old_msg.blank?
     original_msg = original_msg +
     "<div class='freshdesk_quote'>" +
     "<blockquote class='freshdesk_quote'>" + old_msg + "</blockquote>" +
     "</div>"
    end   
    return original_msg
end
    def get_envelope_to
      envelope = params[:envelope]
      envelope_to = envelope.nil? ? [] : (ActiveSupport::JSON.decode envelope)['to']
      envelope_to
    end    
  
end
