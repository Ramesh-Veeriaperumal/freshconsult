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
    return act_on.send("#{action_key}=", value) if act_on.respond_to?("#{action_key}=")
    
    puts "From the trigger of Action... Looks like #{action_key} is not supported!"
  end
  
  protected
  
    def add_comment(act_on)
      note = act_on.notes.build()
      note.body = act_hash[:comment]
      note.account_id = act_on.account_id
      note.user = User.current
      note.private = "true".eql?(act_hash[:private])
      note.save!
    end
  
    def add_tag(act_on)
      value.split(',').each do |tag_name|
        tag_name.strip!
        tag = Helpdesk::Tag.find_by_name_and_account_id(tag_name, act_on.account_id) || Helpdesk::Tag.new(
            :name => tag_name, :account_id => act_on.account_id)
        act_on.tags << tag
      end
    end

    def send_email_to_requester(act_on)
      Helpdesk::TicketNotifier.deliver_email_to_requester(act_on, 
                                                          Liquid::Template.parse(act_hash[:email_body]).render('ticket' => act_on))
    end
    
    def send_email_to_group(act_on)
      group = get_group(act_on)
      send_internal_email(act_on, group.agent_emails) if group
    end

    def send_email_to_agent(act_on)
      agent = get_agent(act_on)
      send_internal_email(act_on, agent.email) if agent
    end
    
  private
    def get_group(act_on) # this (g == 0) is kind of hack, same goes for agents also.
      g_id = act_hash[:email_to].to_i
      (g_id == 0) ? (act_on.group_id ? act_on.group : nil) : act_on.account.groups.find(g_id)
    end

    def get_agent(act_on)
      a_id = act_hash[:email_to].to_i
      (a_id == 0) ? (act_on.responder_id ? act_on.responder : nil) : act_on.account.users.find(a_id)
    end

    def send_internal_email(act_on, receipients)
      Helpdesk::TicketNotifier.deliver_internal_email(act_on, 
                                                      receipients, 
                                                      Liquid::Template.parse(act_hash[:email_body]).render('ticket' => act_on))
    end

end
