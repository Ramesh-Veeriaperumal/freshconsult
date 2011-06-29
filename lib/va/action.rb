class Va::Action
  attr_accessor :action_key, :act_hash
  
  def initialize(act_hash)
    @act_hash = act_hash
    @action_key = act_hash[:name]
  end
  
  def value
    act_hash[:value]
  end
  
  def trigger(act_on)
       
    return send(action_key, act_on) if respond_to?(action_key)
    if act_on.respond_to?("#{action_key}=")
      act_on.send("#{action_key}=", value)
      
      add_activity(property_message act_on)
      return
    end
    
    puts "From the trigger of Action... Looks like #{action_key} is not supported!"
  end
  
  #POOR CODE - due to time constraint - by SHAN
  def property_message(act_on)
    case action_key
    when 'priority'
      "Changed the priority to <b>#{TicketConstants::PRIORITY_NAMES_BY_KEY[value.to_i]}</b>"
    when 'status'
      "Changed the status to <b>#{TicketConstants::STATUS_NAMES_BY_KEY[value.to_i]}</b>"
    when 'ticket_type'
      "Changed the ticket type to <b>#{TicketConstants::TYPE_NAMES_BY_KEY[value.to_i]}</b>"
    when 'responder_id'
      "Assigned to the agent <b>#{act_on.account.users.find(value.to_i)}</b>"
    when 'group_id'
      "Assigned to the group <b>#{act_on.account.groups.find(value.to_i).name}</b>"
    else
      "Set #{action_key.humanize()} as <b>#{value}</b>"
    end
  end
  
  ##Execution activities temporary storage hack starts here
  def self.initialize_activities
    Thread.current[:scenario_action_log] = []
  end
  
  def add_activity(log_mesg)
    Thread.current[:scenario_action_log] << log_mesg
  end
  
  def self.activities
    Thread.current[:scenario_action_log]
  end
  
  def self.clear_activities
    Thread.current[:scenario_action_log] = nil
  end
  ##Execution activities temporary storage hack ends here
  
  protected
  
    def group_id(act_on)
      g_id = value.to_i
      begin
        group = act_on.account.groups.find(g_id)
      rescue ActiveRecord::RecordNotFound
      end
    
      if group
        act_on.group_id = g_id
        add_activity("Set group as <b>#{group.name}</b>")
      else
        add_activity("<b>Unable to set the group, consider updating this scenario if the group has been deleted recently.</b>")
      end
    end
  
    def add_comment(act_on)
      note = act_on.notes.build()
      note.body = act_hash[:comment]
      note.account_id = act_on.account_id
      note.user = User.current
      note.source = Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"]
      note.incoming = false
      note.private = "true".eql?(act_hash[:private])
      note.save!
      
      add_activity(note.private ? "Added a <b>private note</b>" : "Added a <b>note</b>")
    end
  
    def add_tag(act_on)
      value.split(',').each do |tag_name|
        tag_name.strip!
        tag = Helpdesk::Tag.find_by_name_and_account_id(tag_name, act_on.account_id) || Helpdesk::Tag.new(
            :name => tag_name, :account_id => act_on.account_id)
        act_on.tags << tag unless act_on.tags.include?(tag)
      end
      
      add_activity("Assigned the tag(s) [<b>#{value.split(',').join(', ')}</b>]")
    end

    def send_email_to_requester(act_on)
      Helpdesk::TicketNotifier.send_later(:deliver_email_to_requester, 
                act_on, Liquid::Template.parse(act_hash[:email_body]).render('ticket' => act_on, 
                              'helpdesk_name' => act_on.account.portal_name))
      add_activity("Sent an email to the requester")
    end
    
    def send_email_to_group(act_on)
      group = get_group(act_on)
      if group && !group.agent_emails.empty?
        send_internal_email(act_on, group.agent_emails)
        add_activity("Sent an email to the group <b>#{group.name}</b>")
      end
    end

    def send_email_to_agent(act_on)
      agent = get_agent(act_on)
      if agent
        send_internal_email(act_on, agent.email)
        add_activity("Sent an email to the agent <b>#{agent}</b>")
      end
    end
    
  private
    def get_group(act_on) # this (g == 0) is kind of hack, same goes for agents also.
      begin
        g_id = act_hash[:email_to].to_i
        (g_id == 0) ? (act_on.group_id ? act_on.group : nil) : act_on.account.groups.find(g_id)
      rescue ActiveRecord::RecordNotFound
      end
    end

    def get_agent(act_on)
      a_id = act_hash[:email_to].to_i
      (a_id == 0) ? (act_on.responder_id ? act_on.responder : nil) : act_on.account.users.find(a_id)
    end

    def send_internal_email(act_on, receipients)
      Helpdesk::TicketNotifier.send_later(:deliver_internal_email, 
                act_on, receipients, Liquid::Template.parse(act_hash[:email_body]).render('ticket' => act_on, 
                                            'helpdesk_name' => act_on.account.portal_name))
    end

end
