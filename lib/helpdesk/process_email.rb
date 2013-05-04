class Helpdesk::ProcessEmail < Struct.new(:params)
 
  include EmailCommands
  include ParserUtil
  include Helpdesk::ProcessByMessageId
  
  EMAIL_REGEX = /(\b[-a-zA-Z0-9.'’_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b)/
  MESSAGE_LIMIT = 10.megabytes

  def perform
    from_email = parse_from_email
    to_email = parse_to_email
    account = Account.find_by_full_domain(to_email[:domain])
    if !account.nil? and account.active?
      # clip_large_html
      account.make_current
      encode_stuffs
      kbase_email = account.kbase_email
      if (to_email[:email] != kbase_email) || (get_envelope_to.size > 1)
        email_config = account.email_configs.find_by_to_email(to_email[:email])
        return if email_config && (from_email[:email] == email_config.reply_email)
        user = get_user(account, from_email, email_config)
        Rails.logger.debug "PROCESS USER : #{user.inspect}"
        if !user.blocked?
          ticket = fetch_ticket(account, from_email, user)
          Rails.logger.debug "PROCESS USER : #{ticket.inspect}"
          if ticket
            Rails.logger.debug "PROCESS FROM EMAIL : #{from_email.inspect}"
            Rails.logger.debug "PROCESS TICKET REPLY : #{ticket.reply_email}"
            return if(from_email[:email] == ticket.reply_email) #Premature handling for email looping..
            add_email_to_ticket(ticket, from_email, user)
          else
            Rails.logger.debug "CANNOT FIND TICKET"
            create_ticket(account, from_email, to_email, user, email_config)
          end
        end
      end
      
      begin
        if ((to_email[:email] == kbase_email) || (parse_cc_email && parse_cc_email.include?(kbase_email)))
          create_article(account, from_email, to_email)
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
      Account.reset_current_account
    end 
  end
  
  def create_article(account, from_email, to_email)

    article_params = {}

    email_config = account.email_configs.find_by_to_email(to_email[:email])
    user = get_user(account, from_email,email_config)
    
    article_params[:title] = params[:subject].gsub(Regexp.new("\\[#{account.ticket_id_delimiter}([0-9]*)\\]"),"")
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
      
      parsed_email = parse_email_text(email_text)
      
      name = parsed_email[:name]
      email = parsed_email[:email]

      if((email && !(email =~ EMAIL_REGEX) && (email_text =~ EMAIL_REGEX)) || (email_text =~ EMAIL_REGEX))
        email = $1 
      end


      name ||= ""
      domain = (/@(.+)/).match(email).to_a[1]
      
      {:name => name, :email => email, :domain => domain}
    end
    
    def orig_email_from_text #To process mails fwd'ed from agents
      content = params[:text] || Helpdesk::HTMLSanitizer.clean(params[:html])
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
      if(!headers.nil? && headers =~ /Reply-[tT]o: (.+)$/)
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

    def parse_to_emails
      to_emails = params[:to].split(",") if params[:to]
      parsed_to_emails = []
      (to_emails || []).each do |email|
        parsed_email = parse_email_text(email)
        parsed_to_emails.push("#{parsed_email[:name]} <#{parsed_email[:email].strip}>") if !parsed_email.blank? && !parsed_email[:email].blank?
      end
      parsed_to_emails
    end

    def fetch_ticket(account, from_email, user)
      display_id = Helpdesk::Ticket.extract_id_token(params[:subject], account.ticket_id_delimiter)
      Rails.logger.debug "PROCESS display_id : #{display_id}"
      ticket = account.tickets.find_by_display_id(display_id) if display_id
      Rails.logger.debug "PROCESS USER inside fetch : #{ticket.inspect}"
      return ticket if can_be_added_to_ticket?(ticket, user)
      ticket = ticket_from_headers(from_email, account)
      Rails.logger.debug "PROCESS USER failed first check : #{ticket.inspect}"
      return ticket if can_be_added_to_ticket?(ticket, user)
    end
    
    def create_ticket(account, from_email, to_email, user, email_config)            
      if (user.agent? && !user.deleted?)
        e_email = orig_email_from_text
        user = get_user(account, e_email , email_config) unless e_email.nil?
      end
     
      ticket = Helpdesk::Ticket.new(
        :account_id => account.id,
        :subject => params[:subject],
        :description => params[:text],
        :description_html => Helpdesk::HTMLSanitizer.clean(params[:html]),
        :requester => user,
        :to_email => to_email[:email],
        :to_emails => parse_to_emails,
        :cc_email => {:cc_emails => parse_cc_email, :fwd_emails => []},
        :email_config => email_config,
        :status => Helpdesk::Ticketfields::TicketStatus::OPEN,
        :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:email]
      )
      ticket = check_for_chat_scources(ticket,from_email)
      ticket = check_for_spam(ticket)
      check_for_auto_responders(ticket)
      check_support_emails_from(account, ticket, user)

      begin
        if (user.agent? && !user.deleted?)
          process_email_commands(ticket, user, email_config)
          email_cmds_regex = get_email_cmd_regex(account)
          ticket.description = ticket.description.gsub(email_cmds_regex, "") if(!ticket.description.blank? && email_cmds_regex)
          ticket.description_html = ticket.description_html.gsub(email_cmds_regex, "") if(!ticket.description_html.blank? && email_cmds_regex)
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
      message_key = message_id
      begin
        build_attachments(ticket, ticket)
        (ticket.header_info ||= {}).merge!(:message_ids => [message_key]) unless message_key.nil?
        ticket.save!
      rescue ActiveRecord::RecordInvalid => e
        FreshdeskErrorsMailer.deliver_error_email(ticket,params,e)
      end
      set_key(message_key(account, message_key), ticket.display_id, 86400*7) unless message_key.nil?
    end
    
    def check_for_spam(ticket)
      ticket.spam = true if ticket.requester.deleted?
      ticket  
    end
  
    def check_for_chat_scources(ticket,from_email)
      ticket.source = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:chat] if Helpdesk::Ticket::CHAT_SOURCES.has_value?(from_email[:domain])
      if from_email[:domain] == Helpdesk::Ticket::CHAT_SOURCES[:snapengage]
        emailreg = Regexp.new(/\b[-a-zA-Z0-9.'’_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b/)
        chat_email =  params[:subject].scan(emailreg).uniq[0]
        ticket.email = chat_email unless chat_email.blank? && (chat_email == "unknown@example.com")
      end
      ticket
    end
    
    def check_for_auto_responders(ticket)
      headers = params[:headers]
      if(!headers.blank? && ((headers =~ /Auto-Submitted: auto-(.)+/i) || (headers =~ /Precedence: auto_reply/) || ((headers =~ /Precedence: (bulk|junk)/i) && (headers =~ /Reply-To: <>/i) )))
        ticket.skip_notification = true
      end
    end

    def check_support_emails_from(account, ticket, user)
      ticket.skip_notification = true if user && account.support_emails.any? {|email| email.casecmp(user.email) == 0}
    end

    def add_email_to_ticket(ticket, from_email, user)
      body = show_quoted_text(params[:text],ticket.reply_email)
      body_html = show_quoted_text(Helpdesk::HTMLSanitizer.clean(params[:html]), ticket.reply_email)
      from_fwd_recipients = from_fwd_emails?(ticket, from_email)
      parsed_cc_emails = parse_cc_email
      parsed_cc_emails.delete(ticket.account.kbase_email)
      note = ticket.notes.build(
        :private => (from_fwd_recipients and user.customer?) ? true : false ,
        :incoming => true,
        :body => body,
        :body_html => body_html ,
        :source => from_fwd_recipients ? Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"] : 0, #?!?! use SOURCE_KEYS_BY_TOKEN - by Shan
        :user => user, #by Shan temp
        :account_id => ticket.account_id,
        :from_email => from_email[:email],
        :to_emails => parse_to_emails,
        :cc_emails => parsed_cc_emails
      )       
      note.source = Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"] unless user.customer?
      
      begin
        ticket.cc_email = ticket_cc_emails_hash(ticket)
        if (user.agent? && !user.deleted?)
          ticket.responder ||= user
          process_email_commands(ticket, user, ticket.email_config, note)
          email_cmds_regex = get_email_cmd_regex(ticket.account)
          note.body = body.gsub(email_cmds_regex, "") if(!body.blank? && email_cmds_regex)
          note.body_html = body_html.gsub(email_cmds_regex, "") if(!body_html.blank? && email_cmds_regex)
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
      build_attachments(ticket, note)
      # ticket.save
      note.notable = ticket
      note.save
    end
    
    def can_be_added_to_ticket?(ticket,user)
      ticket and
      ((user.agent? && !user.deleted?) or
      (ticket.requester.email and ticket.requester.email.include?(user.email)) or 
      (ticket.included_in_cc?(user.email)) or
      belong_to_same_company?(ticket,user))
    end
    
    def belong_to_same_company?(ticket,user)
      user.customer_id and (user.customer_id == ticket.requester.customer_id)
    end
    
    def get_user(account, from_email, email_config)
      user = account.all_users.find_by_email(from_email[:email])
      unless user
        user = account.contacts.new
        portal = (email_config && email_config.product) ? email_config.product.portal : account.main_portal
        user.signup!({:user => {:email => from_email[:email], :name => from_email[:name], 
          :user_role => User::USER_ROLES_KEYS_BY_TOKEN[:customer]}, :email_config => email_config},portal)
      end
      user.make_current
      user
    end

    def build_attachments(ticket, item)
      content_ids = params["content-ids"].nil? ? {} : get_content_ids
      content_id_hash = {}
     
      Integer(params[:attachments]).times do |i|
        if content_ids["attachment#{i+1}"]
          description = "content_id"
        end
        begin
          created_attachment = item.attachments.build(:content => params["attachment#{i+1}"], 
            :account_id => ticket.account_id,:description => description)
        rescue Exception => e
          Rails.logger.error("Error while adding item attachments for ::: #{e.message}")
          break
        end
        file_name = created_attachment.content_file_name
        if content_ids["attachment#{i+1}"]
          content_id_hash[file_name] = content_ids["attachment#{i+1}"]
          created_attachment.description = "content_id"
        end
      end
      item.header_info = {:content_ids => content_id_hash} unless content_id_hash.blank?
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
      
      #Sanitizing the original msg   
      unless original_msg.blank?
        sanitized_org_msg = Nokogiri::HTML(original_msg).at_css("body")
        original_msg = sanitized_org_msg.inner_html unless sanitized_org_msg.blank?  
      end
      #Sanitizing the old msg   
      unless old_msg.blank?
        sanitized_old_msg = Nokogiri::HTML(old_msg).at_css("body")
        old_msg = sanitized_old_msg.inner_html unless sanitized_old_msg.blank?  
      end
        
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
    
    def from_fwd_emails?(ticket,from_email)
      cc_email_hash_value = ticket.cc_email_hash
      unless cc_email_hash_value.nil?
        cc_email_hash_value[:fwd_emails].any? {|email| email.include?(from_email[:email]) }
      else
        false
      end
    end

    def ticket_cc_emails_hash(ticket)
      cc_email_hash_value = ticket.cc_email_hash.nil? ? {:cc_emails => [], :fwd_emails => []} : ticket.cc_email_hash
      cc_emails_val =  parse_cc_email
      cc_emails_val.delete(ticket.account.kbase_email)
      cc_emails_val.delete_if{|email| (email == ticket.requester.email)}
      cc_email_hash_value[:cc_emails] = cc_emails_val | cc_email_hash_value[:cc_emails]
      cc_email_hash_value
    end

    def clip_large_html
      return unless params[:html]
      @description_html = Helpdesk::HTMLSanitizer.clean(params[:html])
      if @description_html.bytesize > MESSAGE_LIMIT
        Rails.logger.debug "$$$$$$$$$$$$$$$$$$ --> Message over sized so we are trimming it off! <-- $$$$$$$$$$$$$$$$$$"
        @description_html = "#{@description_html[0,MESSAGE_LIMIT]}<b>[message_cliped]</b>"
      end
    end
end
