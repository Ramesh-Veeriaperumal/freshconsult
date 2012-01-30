module EmailCommands 

  include TicketConstants
  
  EMAIL_COMMANDS_REGEX = "(\s*((.+)\s*:\s*(.+)(,)*)*\s*)"

  def process_email_commands(ticket, user, email_config)
    content = params[:text] || Helpdesk::HTMLSanitizer.clean(params[:html] )
    begin
      email_cmds_regex = get_email_cmd_regex(ticket.account)
      if email_cmds_regex && (content =~ email_cmds_regex)
        custom_ff_fields = {}
        cmds = ActiveSupport::JSON.decode("{ #{$1} }")  
        cmds.each_pair do |cmd, value|
        begin
            cmd = cmd.downcase
            if respond_to?(cmd)
              send(cmd,ticket,value)
            elsif !ticket.respond_to?(cmd)
              custom_field = ticket.account.ticket_fields.find_by_label(cmd);    
              custom_ff_fields[custom_field.name.to_sym] = value unless custom_field.blank?
            end                
          rescue Exception => e
            # Do Nothing
          end
        end
        ticket.custom_field = custom_ff_fields  unless custom_ff_fields.blank?
      end
    rescue
      #Do nothing
    end
  end
  
  def get_email_cmd_regex(account)
    delimeter = account.email_commands_setting.email_cmds_delimeter
    email_cmds_regex = Regexp.new("#{delimeter} #{EMAIL_COMMANDS_REGEX} #{delimeter}") unless delimeter.blank?
    email_cmds_regex
  end
  
  def source(ticket, value)
    ticket.source = SOURCE_KEYS_BY_TOKEN[value.to_sym] unless SOURCE_KEYS_BY_TOKEN[value.to_sym].blank?;    
  end
  
  def status(ticket, value)
    ticket.status = STATUS_KEYS_BY_TOKEN[value.to_sym] unless STATUS_KEYS_BY_TOKEN[value.to_sym].blank?; 
  end
  
  def priority(ticket, value)
    ticket.priority = PRIORITY_KEYS_BY_TOKEN[value.to_sym] unless PRIORITY_KEYS_BY_TOKEN[value.to_sym].blank?;
  end
  
  def group(ticket, value)
    group = ticket.account.groups.find_by_name(value)      
    ticket.group = group unless group.nil?
  end
  
  def agent(ticket, value)
    responder = User.find_by_email_or_name(value,ticket.account.id)  ########### Move This to Agent model as self method 
    ticket.responder = responder if responder && responder.agent?
  end
  
  def product(ticket, value)
    email_config = ticket.account.email_configs.find_by_name(value)
    ticket.email_config = email_config unless email_config.blank? 
  end
end