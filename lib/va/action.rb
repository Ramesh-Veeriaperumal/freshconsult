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
      template = Liquid::Template.parse("Sending email to requester as part of VA rule action.. #{act_hash[:email_body]}. And ticket id is {{ticket.display_id}}")
      Helpdesk::TicketNotifier.deliver_email_to_requester(act_on, template.render('ticket' => act_on.attributes))
    end
    
    def send_email_to_group(act_on)
      #TO DO..
    end

    def send_email_to_agent(act_on) #by Shan to do - liquid template
      Helpdesk::TicketNotifier.deliver_internal_email(act_on, act_on.responder.email, "You have got an mail!")
    end
  
#    def priority(act_on)
#      act_on.priority = act_hash[:value]
#    end
end
