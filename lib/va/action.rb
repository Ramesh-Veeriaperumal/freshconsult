class Va::Action
  
  include Va::Webhook::Trigger
  include ParserUtil
  
  EVENT_PERFORMER = -2
  ASSIGNED_AGENT = ASSIGNED_GROUP = 0

  attr_accessor :action_key, :act_hash, :doer, :triggered_event, :va_rule

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
  
  def initialize(act_hash, va_rule = nil)
    @act_hash = act_hash
    @action_key = act_hash[:name]
    @va_rule = va_rule
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
        record_action
        return
      else
        clazz = @action_key.constantize
        obj = clazz.new
        if obj.respond_to?(value)
          act_hash[:va_rule] = @va_rule if act_hash.delete(:include_va_rule)
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
  
  def record_action(params = nil)
    return if !is_automation_rule?
    performer = @doer
    Va::ScenarioFlashMessage.new(act_hash, performer, false).record_activity(params)
  end

  def record_action_for_bulk(user)
    return if !is_automation_rule?
    performer = user
    Va::ScenarioFlashMessage.new(act_hash, performer, true).record_activity
  end

  def group_id(act_on)
    g_id = value.to_i
    begin
      group = act_on.account.groups.find(g_id)
    rescue ActiveRecord::RecordNotFound
    end
    act_on.group = group if group || value.empty?
    record_action(group)
  end

  def responder_id(act_on)
    r_id = value.to_i
    begin
      responder = (r_id == EVENT_PERFORMER) ? (doer.agent? ? doer : nil) : act_on.account.users.find(value.to_i)
    rescue ActiveRecord::RecordNotFound
    end
    act_on.responder = responder if responder || value.empty?
    record_action(responder)
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
    record_action
  end
  
  def add_watcher(act_on)
    watchers = Array.new
    watcher_value = value.kind_of?(Array) ? value : value.to_a
    watcher_value.each do |watcher_id|
      watcher = act_on.subscriptions.find_by_user_id(watcher_id)
      unless watcher.present?
        user = Account.current.users.find_by_id(watcher_id)
        subscription = act_on.subscriptions.build(:user_id => watcher_id)
        if user && user.agent? && subscription.save
          watchers.push subscription.user.name
          Helpdesk::WatcherNotifier.send_later(:deliver_notify_new_watcher, 
                                                act_on, 
                                                subscription, 
                                                "automations rule")
        end
      end
    end
    record_action(watchers) if watchers.present?
  end

  def add_tag(act_on)
    value.split(',').each do |tag_name|
      tag_name.strip!
      tag = Helpdesk::Tag.find_by_name_and_account_id(tag_name, act_on.account_id) || Helpdesk::Tag.new(
          :name => tag_name, :account_id => act_on.account_id)
      act_on.tags << tag unless act_on.tags.include?(tag)
    end
    record_action
  rescue ActiveRecord::RecordInvalid
    Rails.logger.debug "For Va::Action #{self} RecordInvalid Exception rescued"
    last_tag_uses = act_on.tag_uses.last
    last_tag_uses.delete if last_tag_uses.new_record?
  end

  def add_a_cc(act_on)
    unless value.blank? and act_on.cc_email.blank?
      
      ticket_cc_emails = act_on.cc_email[:cc_emails].collect { |email| (parse_email_text email.downcase)[:email] }
      reply_cc_emails  = act_on.cc_email[:reply_cc].collect { |email| (parse_email_text email.downcase)[:email] }
      cc_email_value   = value.downcase.strip
      
      act_on.cc_email[:reply_cc]  << cc_email_value unless reply_cc_emails.include?(cc_email_value)
      
      unless ticket_cc_emails.include?(cc_email_value)
        act_on.cc_email[:cc_emails] << cc_email_value 
              Helpdesk::TicketNotifier.send_later(:send_cc_email, act_on, nil, {:cc_emails => cc_email_value.to_a })
      end
    end
  end

  def send_email_to_requester(act_on)
    if act_on.requester_has_email? && !(act_on.ecommerce? || act_on.requester.ebay_user?)
      act_on.account.make_current
      Helpdesk::TicketNotifier.email_to_requester(act_on, 
        substitute_placeholders_for_requester(act_on, :email_body),
                      substitute_placeholders_for_requester(act_on, :email_subject)) 
      record_action
    end
  end
  
  def send_email_to_group(act_on)
    group = get_group(act_on)
    if group && !group.agent_emails.empty?
      send_internal_email(act_on, group.agent_emails)
      record_action(group)
    end
  end

  def send_email_to_agent(act_on)
    agent = get_agent(act_on)
    if agent
      send_internal_email(act_on, agent.email)
      record_action(agent)
    end
  end
  
  def delete_ticket(act_on)
    act_on.deleted = true
    record_action(act_on)
  end
  
  def mark_as_spam(act_on)
    act_on.spam = true 
    record_action(act_on)
  end

  def skip_notification(act_on)
    act_on.skip_notification = true
  end

  def set_nested_fields(act_on)
    assign_custom_field act_on, @act_hash[:category_name], @act_hash[:value]
    @act_hash[:nested_rules].each do |field|
      assign_custom_field act_on, field[:name], field[:value]
    end
    record_action
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

    def is_automation_rule?
      @va_rule.present? ? @va_rule.automation_rule? : false      
    end
end
