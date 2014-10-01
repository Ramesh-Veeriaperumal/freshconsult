class Va::Action
  
  include Va::Webhook::Trigger
  include ParserUtil
  
  EVENT_PERFORMER = -2
  ASSIGNED_AGENT = ASSIGNED_GROUP = 0

  attr_accessor :action_key, :act_hash, :doer, :triggered_event

  ACTION_PRIVILEGE =
    {  
      :priority                => :edit_ticket_properties,
      :ticket_type             => :edit_ticket_properties,
      :status                  => :edit_ticket_properties,
      :responder_id            => :edit_ticket_properties,
      :group_id                => :edit_ticket_properties,
      :product_id              => :edit_ticket_properties,
      :send_email_to_group     => :reply_ticket,
      :send_email_to_agent     => :reply_ticket,
      :send_email_to_requester => :reply_ticket,
      :delete_ticket           => :delete_ticket
    }
  
  def initialize(act_hash)
    @act_hash = act_hash
    @action_key = act_hash[:name]
  end
  
  def value
    act_hash[:value]
  end
  
  def trigger(act_on, doer=nil, triggered_event=nil)
    begin
      Rails.logger.debug "INSIDE trigger of Va::Action with act_on : #{act_on.inspect} action_key : #{action_key} value: #{value}"
      @doer = doer
      @triggered_event = triggered_event
      return send(action_key, act_on) if respond_to?(action_key)
      if act_on.respond_to?("#{action_key}=")
        act_on.send("#{action_key}=", value)
        add_activity(property_message act_on)
        return
      else
        clazz = @action_key.constantize
        obj = clazz.new
        if obj.respond_to?(value)
          obj.send(value, act_on, act_hash)
          # add_activity(property_message act_on)  # TODO
          return
        end
      end
      
      puts "From the trigger of Action... Looks like #{action_key} is not supported!"
    rescue Exception => e
      Rails.logger.debug "For Va::Action #{self} Exception #{e} rescued"
    end
  end
  
  #POOR CODE - due to time constraint - by SHAN
  def property_message(act_on)
    case action_key
    when 'priority'
      "Changed the priority to <b>#{TicketConstants.priority_list[value.to_i]}</b>"
    when 'status'
      "Changed the status to <b>#{Helpdesk::TicketStatus.status_names_by_key(act_on.account)[value.to_i]}</b>"
    when 'ticket_type'
      "Changed the ticket type to <b>#{value}</b>"
    else
      "Set #{action_key.to_s.humanize()} as <b>#{value}</b>"
    end
  end
  
  ##Execution activities temporary storage hack starts here
  def self.initialize_activities
    Thread.current[:scenario_action_log] = []
  end
  
  def add_activity(log_mesg)
    Thread.current[:scenario_action_log] << log_mesg.html_safe
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

      if group || value.empty?
        act_on.group = group
        add_activity("Set group as <b>#{group.name}</b>") unless group.nil?
      else
        add_activity("<b>Unable to set the group, consider updating this scenario if the group has been deleted recently.</b>")
      end
    end

    def responder_id(act_on)
      r_id = value.to_i
      begin
        responder = (r_id == EVENT_PERFORMER) ? (doer.agent? ? doer : nil) : act_on.account.users.find(value.to_i)
      rescue ActiveRecord::RecordNotFound
      end

      if responder || value.empty?
        act_on.responder = responder
        add_activity("Set agent as <b>#{responder.name}</b>") unless responder.nil?
      else
        add_activity("<b>Unable to set the agent, consider updating this scenario if the agent has been deleted recently.</b>")
      end
    end

    def add_comment(act_on)
      note = act_on.notes.build()
      note.build_note_body
      note.note_body.body_html = substitute_placeholders(act_on, :comment)
      note.account_id = act_on.account_id
      note.user = User.current
      note.source = Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"]
      note.incoming = false
      note.private = "true".eql?(act_hash[:private])
      note.save_note!
      
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

    def add_a_cc(act_on)
      unless value.blank?
        ticket_cc_emails = act_on.cc_email[:cc_emails].collect { |email| (parse_email_text email.downcase)[:email] }
        cc_email_value = value.downcase.strip
        return if ticket_cc_emails.include?(cc_email_value)
        act_on.cc_email[:cc_emails] << cc_email_value
        Helpdesk::TicketNotifier.send_cc_email(act_on,{:cc_emails => cc_email_value.to_a })
      end
    end

    def add_watcher(act_on)
      watchers = Array.new
      watcher_value = value.kind_of?(Array) ? value : value.to_a
      watcher_value.each do |agent_id|
        watcher = act_on.subscriptions.find_by_user_id(agent_id)
        unless watcher.present?
          subscription = act_on.subscriptions.create( {:user_id => agent_id} )
          watchers.push subscription.user.name if subscription
          Helpdesk::WatcherNotifier.send_later(:notify_new_watcher, 
                                               act_on, 
                                               subscription, 
                                               "automations rule")
        end
      end
      add_activity("#{I18n.t('automations.activity.added_watcher(s)')} - <b>#{watchers.to_sentence}</b>") if watchers.present?
    end

    def send_email_to_requester(act_on)
      if act_on.requester_has_email?
        act_on.account.make_current
        Helpdesk::TicketNotifier.email_to_requester(act_on, 
          substitute_placeholders_for_requester(act_on, :email_body),
                        substitute_placeholders_for_requester(act_on, :email_subject)) 
        add_activity("Sent an email to the requester") 
      end
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
    
    def delete_ticket(act_on)
      act_on.deleted = true
      add_activity("Deleted the ticket <b>#{act_on} </b>")
    end
    
    def mark_as_spam(act_on)
      act_on.spam = true 
      add_activity("Marked the ticket <b>#{act_on} </b> as spam")
    end

    def skip_notification(act_on)
      act_on.skip_notification = true
    end

    def set_nested_fields(act_on)
      assign_custom_field act_on, @act_hash[:category_name], @act_hash[:value]
      @act_hash[:nested_rules].each do |field|
        assign_custom_field act_on, field[:name], field[:value]
      end
    end

  private
    def get_group(act_on) # this (g == 0) is kind of hack, same goes for agents also.
      begin
        g_id = act_hash[:email_to].to_i
        (g_id == ASSIGNED_GROUP) ? act_on.group : act_on.account.groups.find(g_id)
      rescue ActiveRecord::RecordNotFound
      end
    end

    def get_agent(act_on)
      begin
        a_id = act_hash[:email_to].to_i
        case a_id
        when ASSIGNED_AGENT
          act_on.responder
        when EVENT_PERFORMER
          doer.agent? ? doer : nil
        else 
          act_on.account.users.find(a_id)
        end
      rescue ActiveRecord::RecordNotFound
      end
    end

    def send_internal_email act_on, receipients
      act_on.account.make_current
      Helpdesk::TicketNotifier.internal_email(act_on, 
        receipients, substitute_placeholders(act_on, :email_body),
          substitute_placeholders(act_on, :email_subject))
    end

    def substitute_placeholders_for_requester act_on, content_key
      act_hash[content_key] = act_hash[content_key].to_s.gsub("{{ticket.status}}",
                                                                "{{ticket.requester_status_name}}")
      substitute_placeholders act_on, content_key
    end

    def substitute_placeholders act_on, content_key     
      content = act_hash[content_key].to_s
      content = RedCloth.new(content).to_html unless content_key == :email_subject
      Liquid::Template.parse(content).render(
                'ticket' => act_on, 'helpdesk_name' => act_on.account.portal_name, 'comment' => act_on.notes.last)
    end

    def assign_custom_field act_on, field, value
      act_on.send "#{field}=", value if act_on.ff_aliases.include? field
    end
end
