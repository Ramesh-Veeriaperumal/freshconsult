# encoding: utf-8
module EmailCommands 

  def process_email_commands(ticket, user, email_config, email_param, note = nil)
    return if ticket.agent_as_requester?(user.id)
    
    content = email_param[:text] || Helpdesk::HTMLSanitizer.plain(email_param[:html])
    begin
      email_cmds_regex = get_email_cmd_regex(ticket.account)
      if email_cmds_regex && (content =~ email_cmds_regex)
        custom_ff_fields = {}
        email_cmds = $1.gsub("\\r\\n","").gsub("\\n","").gsub(/[”“]/,'"') unless $1.blank?
        cmds = ActiveSupport::JSON.decode("{ #{email_cmds} }")  
        Rails.logger.debug "The email commands are : #{cmds}"
        cmds.each_pair do |cmd, value|
          begin
            cmd = cmd.downcase
            if respond_to?(cmd)
              send(cmd,ticket,value,user, note)
            elsif !ticket.respond_to?(cmd)
              custom_field = ticket.account.ticket_fields.find_by_label(cmd)    
              custom_ff_fields[custom_field.name.to_sym] = value unless custom_field.blank?
            end                
          rescue Exception => e
            NewRelic::Agent.notice_error(e)
          end
        end
        ticket.custom_field = custom_ff_fields  unless custom_ff_fields.blank?
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      Rails.logger.debug "!!!ERROR!!! Error in processing email_commands -> #{e}"
    end
  end
  
  def get_email_cmd_regex(account)
    delimeter = account.email_cmds_delimeter
    escaped_delimeter = Regexp.escape(delimeter)
    email_cmds_regex = Regexp.new("#{escaped_delimeter}(.+)#{escaped_delimeter}",Regexp::IGNORECASE | Regexp::MULTILINE) unless escaped_delimeter.blank?
    email_cmds_regex
  end
  
  def source(ticket, value, user, note)
    ticket.source = TicketConstants::SOURCE_KEYS_BY_TOKEN[value.to_sym] unless TicketConstants::SOURCE_KEYS_BY_TOKEN[value.to_sym].blank?    
  end
  
  def type(ticket, value, user, note)
    ticket_types = ticket.account.ticket_types_from_cache.collect {|type| type.value}
    ticket.ticket_type = value if ticket_types.include?(value)
  end
  
  def status(ticket, value, user, note)
    status = Helpdesk::TicketStatus.status_keys_by_name(ticket.account)[value]  
    ticket.status = status unless status.blank?
  end
  
  def priority(ticket, value, user, note)
    ticket.priority = TicketConstants::PRIORITY_KEYS_BY_TOKEN[value.to_sym] unless TicketConstants::PRIORITY_KEYS_BY_TOKEN[value.to_sym].blank?
  end
  
  def group(ticket, value, user, note)
    group = ticket.account.groups.find_by_name(value)      
    ticket.group = group unless group.nil?
    ticket.group = nil if value && (value.casecmp("none") == 0)
  end

  def action(ticket,value,user, note)
    if !note.nil? && (value == "note")
      note.private = true
      note.source = Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"]
    end
  end
  
  def agent(ticket, value, user, note)
    if value && (value.casecmp("me") == 0)
      responder = user
    else
      responder = ticket.account.users.find_by_name(value)
      if responder.nil?
        responder = ticket.account.user_emails.user_for_email(value)
      end
    end
    ticket.responder = responder if responder && responder.agent?
    ticket.responder = nil if value && (value.casecmp("none") == 0)
  end
  
  def product(ticket, value, user, note) #possible dead code, reconsider for removing this command
    product = ticket.account.products.find_by_name(value)
    ticket.product = product unless product
  end
end