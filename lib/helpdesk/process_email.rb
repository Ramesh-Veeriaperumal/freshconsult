# encoding: utf-8
class Helpdesk::ProcessEmail < Struct.new(:params)
 
  include EmailCommands
  include ParserUtil
  include AccountConstants
  include EmailHelper
  include Helpdesk::ProcessByMessageId
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::UrlHelper
  include WhiteListHelper
  include Helpdesk::Utils::Attachment
  include Helpdesk::Utils::ManageCcEmails

  MESSAGE_LIMIT = 10.megabytes

  attr_accessor :reply_to_email, :additional_emails

  def perform
    # from_email = parse_from_email
    to_email = parse_to_email
    shardmapping = ShardMapping.fetch_by_domain(to_email[:domain])
    return unless shardmapping.present?
    Sharding.select_shard_of(to_email[:domain]) do
    account = Account.find_by_full_domain(to_email[:domain])
    if !account.nil? and account.active?
      # clip_large_html
      account.make_current
      encode_stuffs
      from_email = parse_from_email(account)
      return if from_email.nil?
      kbase_email = account.kbase_email
      
      if (to_email[:email] != kbase_email) || (get_envelope_to.size > 1)
        email_config = account.email_configs.find_by_to_email(to_email[:email])
        return if email_config && (from_email[:email] == email_config.reply_email)
        sanitized_html = Helpdesk::HTMLSanitizer.plain(params[:html])
        params[:text] = params[:text] || sanitized_html
        user = get_user(account, from_email, email_config)        
        if !user.blocked?
            # Workaround for params[:html] containing empty tags
          
          self.class.trace_execution_scoped(['Custom/Helpdesk::ProcessEmail/sanitize']) do
            #need to format this code --Suman
            if sanitized_html.blank? && !params[:text].blank? 
             email_cmds_regex = get_email_cmd_regex(account) 
             params[:html] = body_html_with_formatting(params[:text],email_cmds_regex) 
            end
          end  
            
          
          add_to_or_create_ticket(account, from_email, to_email, user, email_config)

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
  end
  
  # ITIL Related Methods starts here

  def add_to_or_create_ticket(account, from_email, to_email, user, email_config)
    ticket = fetch_ticket(account, from_email, user)
    if ticket
      return if(from_email[:email] == ticket.reply_email) #Premature handling for email looping..
      ticket = ticket.parent if can_be_added_to_ticket?(ticket.parent, user)
      add_email_to_ticket(ticket, from_email, user)
    else
      create_ticket(account, from_email, to_email, user, email_config)
    end
  end

  def encoded_display_id_regex account
    Regexp.new("\\[#{account.ticket_id_delimiter}([0-9]*)\\]")
  end
  
  # ITIL Related Methods ends here

  def create_article(account, from_email, to_email)

    article_params = {}

    email_config = account.email_configs.find_by_to_email(to_email[:email])
    user = get_user(account, from_email,email_config)
    
    article_params[:title] = params[:subject].gsub( encoded_display_id_regex(account), "" )
    article_params[:description] = Helpdesk::HTMLSanitizer.clean(params[:html]) || params[:text]
    article_params[:user] = user.id
    article_params[:account] = account.id
    article_params[:content_ids] = params["content-ids"].nil? ? {} : get_content_ids

    article_params[:attachment_info] = JSON.parse(params["attachment-info"]) if params["attachment-info"]
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
      [ :html, :text, :subject, :headers, :from ].each do |t_format|
        unless params[t_format].nil?
          charset_encoding = (charsets[t_format.to_s] || "UTF-8").strip()
          # if !charset_encoding.nil? and !(["utf-8","utf8"].include?(charset_encoding.downcase))
            begin
              params[t_format] = Iconv.new('utf-8//IGNORE', charset_encoding).iconv(params[t_format])
            rescue Exception => e
              mapping_encoding = {
                "ks_c_5601-1987" => "CP949",
                "unicode-1-1-utf-7"=>"UTF-7",
                "_iso-2022-jp$esc" => "ISO-2022-JP",
                "charset=us-ascii" => "us-ascii",
                "iso-8859-8-i" => "iso-8859-8",
                "unicode" => "utf-8"
              }
              if mapping_encoding[charset_encoding.downcase]
                params[t_format] = Iconv.new('utf-8//IGNORE', mapping_encoding[charset_encoding.downcase]).iconv(params[t_format])
              else
                Rails.logger.error "Error While encoding in process email  \n#{e.message}\n#{e.backtrace.join("\n\t")} #{params}"
                NewRelic::Agent.notice_error(e,{:description => "Charset Encoding issue with ===============> #{charset_encoding}"})
              end
            end
          # end
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

    def parse_reply_to_email
      if(!params[:headers].nil? && params[:headers] =~ /^Reply-[tT]o: (.+)$/)
        self.additional_emails = get_email_array($1)[1..-1]
        self.reply_to_email = parse_email($1)
      end
      reply_to_email
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
    
    def parse_from_email account
      reply_to_feature = account.features?(:reply_to_based_tickets)
      parse_reply_to_email if reply_to_feature

      #Assigns email of reply_to if feature is present or gets it from params[:from]
      #Will fail if there is spaces and no key after reply_to or has a garbage string
      f_email = reply_to_email || parse_email(params[:from])
      
      #Ticket will be created for no_reply if there is no other reply_to
      f_email = reply_to_email if valid_from_email?(f_email, reply_to_feature)
      return f_email unless f_email[:email].blank?
    end

    def valid_from_email? f_email, reply_to_feature
      (f_email[:email] =~ /(noreply)|(no-reply)/i or f_email[:email].blank?) and !reply_to_feature and parse_reply_to_email
    end
    
    def parse_cc_email
      cc_array = []
      unless params[:cc].nil?
        cc_array = params[:cc].split(',').collect! {|n| (parse_email n)[:email]}
      end
      cc_array.concat(additional_emails || [])
      return cc_array.compact.map{|i| i.downcase}.uniq
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
      ticket = account.tickets.find_by_display_id(display_id) if display_id
      return ticket if can_be_added_to_ticket?(ticket, user)
      ticket = ticket_from_headers(from_email, account)
      return ticket if can_be_added_to_ticket?(ticket, user)
      ticket = ticket_from_email_body(account)
      return ticket if can_be_added_to_ticket?(ticket, user)
      ticket = ticket_from_id_span(account)
      return ticket if can_be_added_to_ticket?(ticket, user)
    end
    
    def create_ticket(account, from_email, to_email, user, email_config)            
      e_email = {}
      if (user.agent? && !user.deleted?)
        e_email = orig_email_from_text || {}
        user = get_user(account, e_email , email_config) unless e_email.blank?
      end
     
      ticket = Helpdesk::Ticket.new(
        :account_id => account.id,
        :subject => params[:subject],
        :ticket_body_attributes => {:description => params[:text], 
                          :description_html => Helpdesk::HTMLSanitizer.clean(params[:html])},
        :requester => user,
        :to_email => to_email[:email],
        :to_emails => parse_to_emails,
        :cc_email => {:cc_emails => parse_cc_email, :fwd_emails => [], :reply_cc => parse_cc_email},
        :email_config => email_config,
        :status => Helpdesk::Ticketfields::TicketStatus::OPEN,
        :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:email]
      )
      ticket.sender_email = e_email[:email] || from_email[:email]
      ticket = check_for_chat_scources(ticket,from_email)
      ticket = check_for_spam(ticket)
      check_for_auto_responders(ticket)
      check_support_emails_from(account, ticket, user, from_email)

      begin
        if (user.agent? && !user.deleted?)
          process_email_commands(ticket, user, email_config, params) if user.privilege?(:edit_ticket_properties)
          email_cmds_regex = get_email_cmd_regex(account)
          ticket.ticket_body.description = ticket.description.gsub(email_cmds_regex, "") if(!ticket.description.blank? && email_cmds_regex)
          ticket.ticket_body.description_html = ticket.description_html.gsub(email_cmds_regex, "") if(!ticket.description_html.blank? && email_cmds_regex)
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
      message_key = zendesk_email || message_id
      begin
        self.class.trace_execution_scoped(['Custom/Helpdesk::ProcessEmail/attachments_tickets']) do
          build_attachments(ticket, ticket)
          (ticket.header_info ||= {}).merge!(:message_ids => [message_key]) unless message_key.nil?
          ticket.save_ticket!
        end
      rescue AWS::S3::Errors::InvalidURI => e
        # FreshdeskErrorsMailer.deliver_error_email(ticket,params,e)
        raise e
      rescue ActiveRecord::RecordInvalid => e
        # FreshdeskErrorsMailer.deliver_error_email(ticket,params,e)
      end
      set_others_redis_key(message_key(account, message_key), ticket.display_id, 86400*7) unless message_key.nil?
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
      if(!headers.blank? && ((headers =~ /Auto-Submitted: auto-(.)+/i) || (headers =~ /Precedence: auto_reply/) || (headers =~ /Precedence: (bulk|junk)/i)))
        ticket.skip_notification = true
      end
    end

    def check_support_emails_from(account, ticket, user, from_email)
      ticket.skip_notification = true if user && account.support_emails.any? {|email| email.casecmp(from_email[:email]) == 0}
    end

    def ticket_from_email_body(account)
      display_span = Nokogiri::HTML(params[:html]).css("span[title='fd_tkt_identifier']")
      unless display_span.blank?
        display_id = display_span.last.inner_html
        return account.tickets.find_by_display_id(display_id.to_i) unless display_id.blank?
      end
    end

    def ticket_from_id_span(account)
      parsed_html = Nokogiri::HTML(params[:html])
      display_span = parsed_html.css("span[style]").select{|x| x.to_s.include?('fdtktid')}
      unless display_span.blank?
        display_id = display_span.last.inner_html
        display_span.last.remove
        params[:html] = parsed_html.inner_html
        return account.tickets.find_by_display_id(display_id.to_i) unless display_id.blank?
      end
    end

    def add_email_to_ticket(ticket, from_email, user)
      msg_hash = {}
      # for plain text
      msg_hash = show_quoted_text(params[:text],ticket.reply_email)
      unless msg_hash.blank?
        body = msg_hash[:body]
        full_text = msg_hash[:full_text]
      end
      # for html text
      msg_hash = show_quoted_text(Helpdesk::HTMLSanitizer.clean(params[:html]), ticket.reply_email,false)
      unless msg_hash.blank?
        body_html = msg_hash[:body]
        full_text_html = msg_hash[:full_text]
      end
      
      from_fwd_recipients = from_fwd_emails?(ticket, from_email)
      parsed_cc_emails = parse_cc_email
      parsed_cc_emails.delete(ticket.account.kbase_email)
      note = ticket.notes.build(
        :private => (from_fwd_recipients and user.customer?) ? true : false ,
        :incoming => true,
        :note_body_attributes => {:body => body,:body_html => body_html,
                                  :full_text => full_text, :full_text_html => full_text_html} ,
        :source => from_fwd_recipients ? Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"] : 0, #?!?! use SOURCE_KEYS_BY_TOKEN - by Shan
        :user => user, #by Shan temp
        :account_id => ticket.account_id,
        :from_email => from_email[:email],
        :to_emails => parse_to_emails,
        :cc_emails => parsed_cc_emails
      )  
      note.subject = Helpdesk::HTMLSanitizer.clean(params[:subject])   
      note.source = Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"] unless user.customer?
      
      begin
        ticket.cc_email = ticket_cc_emails_hash(ticket, note)
        if (user.agent? && !user.deleted?)
          process_email_commands(ticket, user, ticket.email_config, params, note) if 
            user.privilege?(:edit_ticket_properties)
          email_cmds_regex = get_email_cmd_regex(ticket.account)
          note.note_body.body = body.gsub(email_cmds_regex, "") if(!body.blank? && email_cmds_regex)
          note.note_body.body_html = body_html.gsub(email_cmds_regex, "") if(!body_html.blank? && email_cmds_regex)
          note.note_body.full_text = full_text.gsub(email_cmds_regex, "") if(!full_text.blank? && email_cmds_regex)
          note.note_body.full_text_html = full_text_html.gsub(email_cmds_regex, "") if(!full_text_html.blank? && email_cmds_regex)
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
      self.class.trace_execution_scoped(['Custom/Helpdesk::ProcessEmail/attachments_notes']) do
        build_attachments(ticket, note)
        # ticket.save
        note.notable = ticket
        note.save_note
      end
    end
    
    def can_be_added_to_ticket?(ticket,user)
      ticket and
      ((user.agent? && !user.deleted?) or
      (ticket.requester.email and ticket.requester.email.include?(user.email)) or 
      (ticket.included_in_cc?(user.email)) or
      belong_to_same_company?(ticket,user))
    end
    
    def belong_to_same_company?(ticket,user)
      user.company_id and (user.company_id == ticket.requester.company_id)
    end
    
    def get_user(account, from_email, email_config)
      user = account.user_emails.user_for_email(from_email[:email])
      unless user
        user = account.contacts.new
        language = (account.features?(:dynamic_content)) ? nil : account.language
        portal = (email_config && email_config.product) ? email_config.product.portal : account.main_portal
        signup_status = user.signup!({:user => {:email => from_email[:email], :name => from_email[:name], 
          :helpdesk_agent => false, :language => language, :created_from_email => true }, :email_config => email_config},portal)        
        text = text_for_detection
        args = [user, text]  #user_email changed
        #Delayed::Job.enqueue(Delayed::PerformableMethod.new(Helpdesk::DetectUserLanguage, :set_user_language!, args), nil, 1.minutes.from_now) if language.nil? and signup_status
        Resque::enqueue_at(1.minute.from_now, Workers::DetectUserLanguage, {:user_id => user.id, :text => text, :account_id => Account.current.id}) if language.nil? and signup_status
      end
      user.make_current
      user
    end

    def text_for_detection
      text = params[:text][0..100]
      text.gsub("\n","").squeeze(" ").split(" ")[0..5].join(" ")
    end

    def build_attachments(ticket, item)
      content_ids = params["content-ids"].nil? ? {} : get_content_ids
      content_id_hash = {}
     
      attachment_info = JSON.parse(params["attachment-info"]) if params["attachment-info"]
      Integer(params[:attachments]).times do |i|
      description = content_ids["attachment#{i+1}"] ? "content_id" : ""
        begin
          created_attachment = {:content => params["attachment#{i+1}"], 
            :account_id => ticket.account_id,:description => description}
            created_attachment = create_attachment_from_params(item, created_attachment,
                                    (attachment_info.present? ? attachment_info["attachment#{i+1}"] : nil),"attachment#{i+1}")
        rescue HelpdeskExceptions::AttachmentLimitException => ex
          Rails.logger.error("ERROR ::: #{ex.message}")
          add_notification_text item
          break
        rescue Exception => e
          Rails.logger.error("Error while adding item attachments for ::: #{e.message}")
          break
        end
        file_name = created_attachment.content_file_name
        unique_file_name = file_name + "#{i}"
        if content_ids["attachment#{i+1}"]
          content_id_hash[unique_file_name] = content_ids["attachment#{i+1}"]
          created_attachment.description = "content_id"
        end
      end
      item.header_info = {:content_ids => content_id_hash} unless content_id_hash.blank?
    end

    def add_notification_text item
      message = attachment_exceeded_message(HelpdeskAttachable::MAX_ATTACHMENT_SIZE)
      notification_text = "\n" << message
      notification_text_html = Helpdesk::HTMLSanitizer.clean(content_tag(:div, message, :class => "attach-error"))
      if item.is_a?(Helpdesk::Ticket)
        item.description << notification_text
        item.description_html << notification_text_html
      elsif item.is_a?(Helpdesk::Note)
        item.body << notification_text
        item.body_html << notification_text_html
      end
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
  
    def show_quoted_text(text, address,plain=true)
      
      return text if text.blank?
      
      regex_arr = [
        Regexp.new("From:\s*" + Regexp.escape(address), Regexp::IGNORECASE),
        Regexp.new("<" + Regexp.escape(address) + ">", Regexp::IGNORECASE),
        Regexp.new(Regexp.escape(address) + "\s+wrote:", Regexp::IGNORECASE),   
        Regexp.new("\\n.*.\d.*." + Regexp.escape(address) ),
        Regexp.new("<div>\n<br>On.*?wrote:"), #iphone
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
      
      return  {:body => original_msg, :full_text => text } if plain
      #Sanitizing the original msg   
      unless original_msg.blank?
        sanitized_org_msg = Nokogiri::HTML(original_msg).at_css("body")
        unless sanitized_org_msg.blank?
          remove_identifier_span(sanitized_org_msg)
          original_msg = sanitized_org_msg.inner_html
        end
      end
      #Sanitizing the old msg   
      unless old_msg.blank?
        sanitized_old_msg = Nokogiri::HTML(old_msg).at_css("body")
        unless sanitized_old_msg.blank? 
          remove_identifier_span(sanitized_old_msg)
          old_msg = sanitized_old_msg.inner_html 
        end
      end
        
      full_text = original_msg
      unless old_msg.blank?

       full_text = full_text +
       "<div class='freshdesk_quote'>" +
       "<blockquote class='freshdesk_quote'>" + old_msg + "</blockquote>" +
       "</div>"
      end 
      {:body => full_text,:full_text => full_text}  #temp fix made for showing quoted text in incoming conversations
    end

    def remove_identifier_span msg
      id_span = msg.css("span[title='fd_tkt_identifier']")
      id_span.remove if id_span
    end

    def get_envelope_to
      envelope = params[:envelope]
      envelope_to = envelope.nil? ? [] : (ActiveSupport::JSON.decode envelope)['to']
      envelope_to
    end    
    
    def from_fwd_emails?(ticket,from_email)
      cc_email_hash_value = ticket.cc_email_hash
      unless cc_email_hash_value.nil?
        cc_email_hash_value[:fwd_emails].any? {|email| email.include?(from_email[:email].downcase) }
      else
        false
      end
    end

    def ticket_cc_emails_hash(ticket, note)
      cc_email_hash_value = ticket.cc_email_hash.nil? ? {:cc_emails => [], :fwd_emails => [], :reply_cc => []} : ticket.cc_email_hash
      cc_emails_val =  parse_cc_email
      cc_emails_val.delete(ticket.account.kbase_email)
      cc_emails_val.delete_if{|email| (email == ticket.requester.email)}
      add_to_reply_cc(cc_emails_val, ticket, note, cc_email_hash_value)
      cc_email_hash_value[:cc_emails] = cc_emails_val | cc_email_hash_value[:cc_emails].compact.collect! {|x| (parse_email x)[:email]}
      cc_email_hash_value
    end

    #possible unwanted code. Not used now.
    def clip_large_html
      return unless params[:html]
      @description_html = Helpdesk::HTMLSanitizer.clean(params[:html])
      if @description_html.bytesize > MESSAGE_LIMIT
        Rails.logger.debug "$$$$$$$$$$$$$$$$$$ --> Message over sized so we are trimming it off! <-- $$$$$$$$$$$$$$$$$$"
        @description_html = "#{@description_html[0,MESSAGE_LIMIT]}<b>[message_cliped]</b>"
      end
    end

    #remove Redcloth from formatting
    def body_html_with_formatting(body,email_cmds_regex)
      body = body.gsub(email_cmds_regex,'<notextile>\0</notextile>')
      body_html = auto_link(body) { |text| truncate(text, 100) }
      textilized = RedCloth.new(body_html.gsub(/\n/, '<br />'), [ :hard_breaks ])
      textilized.hard_breaks = true if textilized.respond_to?("hard_breaks=")
      white_list(textilized.to_html)
    end
    
end
