class Va::Action
  
  include Va::Action::Restrictions
  include Va::Webhook::Trigger
  include Va::Observer::Constants
  include ParserUtil
  include Concerns::ApplicationViewConcern
  include Concerns::TicketsViewConcern

  #including Redis keys for notify_cc - will be removed later
  include Redis::RedisKeys
  include Redis::OthersRedis
  
  EVENT_PERFORMER = -2
  ASSIGNED_AGENT = ASSIGNED_GROUP = 0
  ACTION_ERROR = 'ACTION_FAILED'.freeze
  SPECIAL_CHARACTERS_TO_IGNORE = ['hyphen', 'exclamation'].freeze

  attr_accessor :action_key, :act_hash, :doer, :triggered_event, :va_rule, :skip_record_action, :logger_actions

  IRREVERSIBLE_ACTIONS = [:add_comment, :add_watcher, :send_email_to_agent, 
    :send_email_to_group, :send_email_to_requester, :forward_ticket, :add_tag, 
    :delete_ticket, :mark_as_spam, :internal_group_id, :internal_agent_id, :add_note]

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
  
  def trigger(act_on, doer=nil, triggered_event=nil, only_reversible_actions = false, original_ticket = nil)
    begin
      if only_reversible_actions && IRREVERSIBLE_ACTIONS.include?(action_key.to_sym)
        Rails.logger.debug "In validation, Skipping trigger act_on : #{act_on.inspect} action_key : #{action_key}"
        return
      end
      @skip_record_action = only_reversible_actions
      @doer = doer
      @original_ticket = original_ticket
      @triggered_event = triggered_event
      Va::Logger::Automation.log "action=#{action_key.inspect}, value=#{value.inspect}"
      return safe_send(action_key, act_on) if respond_to?(action_key)

      Thread.current[:dispatcher_set_priority] = true if action_key == 'priority' && va_rule.dispatchr_rule?
      if act_on.respond_to?("#{action_key}=")
        act_on.safe_send("#{action_key}=", value)
        record_action(act_on)
        return
      else
        @action_key = @action_key.try(:to_s) if @action_key.is_a?(Symbol)
        clazz = @action_key.constantize
        obj = clazz.new
        if obj.respond_to?(value)
          act_hash[:va_rule] = @va_rule if act_hash.delete(:include_va_rule)
          obj.safe_send(value, act_on, act_hash)
          # add_activity(property_message act_on)  # TODO
          return
        end
      end
      Va::Logger::Automation.log "unsupported action=#{action_key}"
    rescue Exception => e
      Va::Logger::Automation.log_error(ACTION_ERROR, e, self)
    end
  end
  
  def record_action(ticket, params = nil)
    return if @skip_record_action
    performer = @doer
    activity_params = {:ticket => ticket}
    activity_params.merge!({
                        :rule_id => @va_rule.id,
                        :is_automation_rule => is_automation_rule?
                        }) if @va_rule.present?
    va_rule_logger = Va::RuleActivityLogger.new(act_hash, performer, false, activity_params)
    @logger_actions = va_rule_logger.act_hash
    va_rule_logger.record_activity(params)
  end

  def record_action_for_bulk(user)
    return if !is_automation_rule?
    performer = user
    va_rule_logger = Va::RuleActivityLogger.new(act_hash, performer, true)
    @logger_actions = va_rule_logger.act_hash
    va_rule_logger.record_activity
  end

  def group_id(act_on)
    g_id = value.to_i
    begin
      group = act_on.account.groups.find(g_id)
    rescue ActiveRecord::RecordNotFound
    end
    act_on.group = group if group || value.blank?
    record_action(act_on, group)
  end

  def internal_group_id(act_on)
    ig_id = value.to_i
    begin
      internal_group = act_on.account.groups.find(ig_id)
    rescue ActiveRecord::RecordNotFound
    end
    act_on.internal_group = internal_group if internal_group || value.empty?
    record_action(act_on, internal_group)
  end

  def responder_id(act_on)
    r_id = value.to_i
    return if r_id == EVENT_PERFORMER && doer.nil?
    begin
      responder = (r_id == EVENT_PERFORMER) ? event_performing_agent(act_on, doer) : act_on.account.technicians.find(value.to_i)
    rescue ActiveRecord::RecordNotFound
    end
    act_on.responder = responder if responder || value.empty?
    record_action(act_on, responder)
  end

  def internal_agent_id(act_on)
    ia_id = value.to_i
    return if ia_id == EVENT_PERFORMER && doer.nil?
    begin
      internal_agent = (ia_id == EVENT_PERFORMER) ? event_performing_agent(act_on, doer) : act_on.account.technicians.find(value.to_i)
    rescue ActiveRecord::RecordNotFound
    end
    act_on.internal_agent = internal_agent if internal_agent || value.empty?
    record_action(act_on, internal_agent)
  end

  def product_id(act_on)
    pr_id = value.to_i
    begin
      product = act_on.account.products.find(pr_id)
    rescue ActiveRecord::RecordNotFound
    end
    act_on.product = product if product || value.empty?
    record_action(act_on, product)
  end

  def add_comment(act_on)
    note_params = { 
      note_body_key: 'comment',
      source:  'note',
      private: 'true'.eql?(act_hash[:private])
    }
    note = build_note act_on, note_params, false
    sanitize_note note
    record_action(act_on)
  end
  
  def add_watcher(act_on)
    return unless Account.current.add_watcher_enabled?
    watchers = {}
    watcher_ids = value.kind_of?(Array) ? value : value.to_a
    watcher_ids.map!(&:to_i)
    resultant_user_ids = act_on.subscriptions.where(user_id: watcher_ids).pluck(:user_id)
    filtered_user_ids = watcher_ids - resultant_user_ids
    if filtered_user_ids.length > 0 
      Account.current.users.where(id: filtered_user_ids).each do |user|
        subscription = act_on.account.ticket_subscriptions.build(:user_id => user.id)
        subscription.ticket_id = act_on.id
        if act_on.agent_performed?(user) && subscription.save
          watchers.merge!({user.id => user.name})
          Helpdesk::WatcherNotifier.send_later(:deliver_notify_new_watcher, 
                                                act_on, 
                                                subscription, 
                                                "automations rule", locale_object: subscription.user)
        end
      end
      record_action(act_on, watchers) if watchers.present?
    end
  end

  def add_tag(act_on)
    tag_arr = []
    value.split(',').each do |tag_name|
      tag_name.strip!
      tag = Helpdesk::Tag.find_by_name_and_account_id(tag_name, act_on.account_id) || Helpdesk::Tag.new(
          :name => tag_name, :account_id => act_on.account_id)
      if !act_on.tags.include?(tag)
        act_on.tags << tag
        tag_arr << tag.name
      end
    end
    record_action(act_on, tag_arr)
  rescue ActiveRecord::RecordInvalid
    Rails.logger.debug "For Va::Action #{self} RecordInvalid Exception rescued"
    last_tag_uses = act_on.tag_uses.last
    last_tag_uses.delete if last_tag_uses.new_record?
  end

  def add_a_cc(act_on)
    unless value.blank? and act_on.cc_email.blank?
      cc_emails        = act_on.cc_email[:cc_emails].collect { |email| (parse_email_text email.downcase)[:email] }
      ticket_cc_emails = act_on.cc_email[:tkt_cc].collect { |email| (parse_email_text email.downcase)[:email] }
      reply_cc_emails  = act_on.cc_email[:reply_cc].collect { |email| (parse_email_text email.downcase)[:email] }
      cc_email_value   = value.downcase.strip

      act_on.cc_email[:reply_cc]  << cc_email_value unless reply_cc_emails.include?(cc_email_value)
      act_on.cc_email[:cc_emails] << cc_email_value unless cc_emails.include?(cc_email_value)
      act_on.cc_email[:tkt_cc]    << cc_email_value unless ticket_cc_emails.include?(cc_email_value)
      
      # send notify_cc_people unless redis key - will be removed later
      unless get_others_redis_key("NOTIFY_CC_ADDED_VIA_DISPATCHER").present? || cc_emails.include?(cc_email_value)
         Helpdesk::TicketNotifier.send_later(:send_cc_email, act_on, nil, {:cc_emails => cc_email_value.to_a })
      end

      record_action(act_on)
    end
  end

  def send_email_to_requester(act_on)
    # We can set rules to send email on trigger event 'marked_spam'. To support that we need to bypass
    # this if condition.
    return if act_on.spam? && !(TICKET_MARKED_SPAM[:ticket_action].to_s == triggered_event[:ticket_action])

    if act_on.requester_has_email? && !(act_on.ecommerce? || act_on.requester.ebay_user?)
      act_on.account.make_current
      if self.va_rule.automation_rule?
        Helpdesk::TicketNotifier.send_later(:email_to_requester, act_on, 
        substitute_placeholders_for_requester(act_on, :email_body),
                      substitute_placeholders_for_requester(act_on, :email_subject))
      else
      Helpdesk::TicketNotifier.email_to_requester(act_on, 
        substitute_placeholders_for_requester(act_on, :email_body),
                      substitute_placeholders_for_requester(act_on, :email_subject)) 
      end
      record_action(act_on)
    end
  end
  
  def send_email_to_group(act_on)
    return if act_on.spam? && !(TICKET_MARKED_SPAM[:ticket_action].to_s == triggered_event[:ticket_action])

    group = get_group(act_on)
    if group && !group.agent_emails.empty?
      send_internal_email(act_on, group.agent_emails)
      record_action(act_on, group)
    end
  end

  def send_email_to_agent(act_on)
    # We can set rules to send email on trigger event 'marked_spam'. To support that we need to bypass
    # this if condition.
    return if (act_on.spam? && !(TICKET_MARKED_SPAM[:ticket_action].to_s == triggered_event[:ticket_action])) || (act_hash[:email_to].to_i == EVENT_PERFORMER && doer.nil?)

    agent = get_agent(act_on)
    if agent
      send_internal_email(act_on, agent.email)
      record_action(act_on, agent)
    end
  end
  
  def forward_ticket(act_on)
    note_params = {
      note_body_key: 'fwd_note_body',
      source:  'automation_rule_forward',
      private: true
    }
    note = build_note act_on, note_params
    last_item = act_on.last_forwardable_note || act_on
    attachments = act_hash[:show_quoted_text] ? (act_on.last_forwardable_note.try(:attachments) || act_on.attachments) : nil
    note.note_body.body_html.concat(quoted_text(last_item, true)) if act_hash[:show_quoted_text]
    note.schema_less_note.to_emails = act_hash[:fwd_to] || []
    note.schema_less_note.cc_emails = act_hash[:fwd_cc] || []
    note.schema_less_note.bcc_emails = act_hash[:fwd_bcc] || []
    note.schema_less_note.from_email = act_on.account.default_email
    [*attachments].each { |att| note.attachments.build(content: att.to_io) } if attachments.present?
    sanitize_note note
    note.safe_send(:add_cc_email)
    activity_params = { helpdesk_name: act_on.account.helpdesk_name, to_emails: act_hash[:fwd_to], cc_emails: act_hash[:fwd_cc], bcc_emails: act_hash[:fwd_bcc] }
    record_action(act_on, activity_params)
  end

  def delete_ticket(act_on)
    act_on.deleted = true
    record_action(act_on, act_on)
  end
  
  def mark_as_spam(act_on)
    act_on.spam = true 
    record_action(act_on, act_on)
  end

  def add_note(act_on)
    note_params = {
      note_body_key: 'note_body',
      source:  'automation_rule',
      private: true
    }
    note = build_note act_on, note_params
    agent_emails = []
    act_hash[:notify_agents] = [].push(act_hash[:notify_agents]) if act_hash[:notify_agents].is_a?(String) 
    (act_hash[:notify_agents]).each do |agent_id|  
      agent_emails<<(act_on.account.users.find(agent_id).email) 
    end
    note.schema_less_note.to_emails = agent_emails
    note.build_note_and_sanitize
    UnicodeSanitizer.encode_emoji(note.note_body, 'body', 'full_text')
    account_name = {account_name: act_on.account.helpdesk_name}
    record_action(act_on,account_name)
  end

  def skip_notification(act_on)
    act_on.skip_notification = true
  end

  def set_nested_fields(act_on)
    assign_custom_field act_on, @act_hash[:category_name], @act_hash[:value]
    @act_hash[:nested_rules].each do |field|
      assign_custom_field act_on, field[:name], field[:value]
    end
    record_action(act_on)
  end

  def contains? action_string
    action_key.include? action_string
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
          event_performing_agent(act_on, doer)
        else 
          act_on.account.technicians.find(a_id)
        end
      rescue ActiveRecord::RecordNotFound
      end
    end

    def event_performing_agent(act_on, doer)
      doer.present? && act_on.agent_performed?(doer) ? doer : nil
    end

    def send_internal_email act_on, receipients
      act_on.account.make_current
      if self.va_rule.automation_rule?
        Helpdesk::TicketNotifier.send_later(:internal_email, act_on, 
        receipients, substitute_placeholders(act_on, :email_body),
          substitute_placeholders(act_on, :email_subject))
       else
         Helpdesk::TicketNotifier.internal_email(act_on, 
         receipients, substitute_placeholders(act_on, :email_body),
           substitute_placeholders(act_on, :email_subject)) 
       end
     end

    def substitute_placeholders_for_requester act_on, content_key
      act_hash[content_key] = act_hash[content_key].to_s.gsub("{{ticket.status}}",
                                                                "{{ticket.requester_status_name}}")
      substitute_placeholders act_on, content_key
    end

    def substitute_placeholders act_on, content_key
      act_on = @original_ticket.present? ? @original_ticket : act_on
      content           = act_hash[content_key].to_s
      # checking whether words are surrouned by hyphen
      content = convert_content_to_html(content, content_key)

      placeholder_hash  = {'ticket' => act_on, 'helpdesk_name' => act_on.account.helpdesk_name,
                           'comment' => act_on.notes.visible.exclude_source(Account.current.helpdesk_sources.note_exclude_sources).last}
      placeholder_hash.merge!('event_performer' => doer) if doer.present?

      # Reference: https://github.com/jgarber/redcloth. RedCloth will support html conversion only when the input is in
      # pure textile format. In automation we are accepting HTML Template Engine codes for notes and emails. Since the
      # Template Engine codes are not convertable to textile, RedCloth coverts them to html tags assuming it is a textile codes.
      # So when we parse the content using Liquid::Template parser (Basically it will evaluate the Template Engine codes and make html out of it)
      # it throws exception. To avoind this issue, applying RedCloth on Liquid::Template parsed output which will be in pure textile format.
      Liquid::Template.parse(content).render(placeholder_hash)
    end

    def assign_custom_field act_on, field, value
      act_on.send "#{field}=", value if act_on.ff_aliases.include? field
    end

    def is_automation_rule?
      @va_rule.present? ? @va_rule.automation_rule? : false      
    end

    def build_note act_on, note_params, system_added = true
      note = act_on.notes.build
      note.build_note_body
      note.build_schema_less_note
      note.account_id = act_on.account_id
      note.note_body.body_html = substitute_placeholders(act_on, note_params[:note_body_key].to_sym)
      note.source = Account.current.helpdesk_sources.note_source_keys_by_token[note_params[:source]]
      note.private = note_params[:private]
      note.user = system_added ? nil : User.current
      note.incoming = false
      note
    end

    def sanitize_note note
      note.build_note_and_sanitize
      UnicodeSanitizer.encode_emoji(note.note_body, 'body', 'full_text')
      note.build_note_schema_less_associated_attributes
    end

    def replace_html_tags_with_spl_characters(con, replace_type)
      if replace_type.include? SPECIAL_CHARACTERS_TO_IGNORE[0]
        con.gsub!(/<del>|<\/del>/, '-') # hyphens get converted to del and &#8212; we are retriving it back
        con.gsub!(/&#8212;/, '--') if con.scan(/&#8212;/).present?
      end
      con.gsub!(/<img.*?src="(.*?)".*?\>/) { |cont| $1.include?('inline/attachment?token=') ? cont : "!#{$1}!" } if replace_type.include? SPECIAL_CHARACTERS_TO_IGNORE[1]
      con
    end

    def convert_content_to_html(content, content_key)
      replace_type = []
      replace_type.push(SPECIAL_CHARACTERS_TO_IGNORE[0]) if content.scan(/(-+\p{L}+.+)|(-+\s+\p{L}+.+)|(\p{L}+-+)|(\p{L}+\s+-+)/u).present?
      replace_type.push(SPECIAL_CHARACTERS_TO_IGNORE[1]) if content.scan(/(!+\p{L}+.+)/).present?
      content = RedCloth.new(content).to_html unless content_key == :email_subject
      Account.current.trim_special_characters_enabled? ? replace_html_tags_with_spl_characters(content, replace_type) : content
    end
end
