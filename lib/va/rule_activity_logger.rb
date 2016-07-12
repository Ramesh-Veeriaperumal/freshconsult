class Va::RuleActivityLogger

  EVENT_PERFORMER = -2
  ACTION_PREFIX = 'automations.activity.'
  DONT_CARE     = ActivityConstants::DONT_CARE_VALUE
  attr_accessor :action_key, :act_hash, :value, :doer, :bulk_scenario, :ticket, :rule_id

  def initialize(act_hash, doer, bulk_scenario = false, activity = {})
    @act_hash      = act_hash
    @action_key    = act_hash[:name]
    @value         = act_hash[:value]
    @doer          = doer
    @bulk_scenario = bulk_scenario
    @is_automation = activity.present? ? activity[:is_automation_rule] : true
    if activity.present?
      @ticket        = activity[:ticket]
      @rule_id       = activity[:rule_id]
    end
  end
  
  ##Execution activities temporary storage hack starts here
  def self.initialize_activities
    Thread.current[:scenario_action_log] = []
  end

  def self.activities
    Thread.current[:scenario_action_log]
  end
  
  def self.clear_activities
    Thread.current[:scenario_action_log] = nil
  end

  # Thread variable will be set only for scenario automation rules
  def self.automation_execution?
    !Thread.current[:scenario_action_log].nil?
  end
  ##Execution activities temporary storage hack ends here

  def record_activity(args = nil)
    message = nil
    if respond_to?("#{action_key}", true)
      message = (args.nil? ? send("#{action_key}") : send("#{action_key}", args))
    else
      message = custom_fields
    end
    add_activity(message) if message.present?
  end

  private

    def add_activity(log_mesg)
      # Thread variable will be set only for scenario automation rules
      Thread.current[:scenario_action_log] << log_mesg.html_safe if @is_automation
    end  

    def activities_enabled?
      Account.current.features?(:activity_revamp) and @ticket.present? and @ticket.respond_to?(:system_changes)
    end

    def add_system_changes(changes)
      return if !(changes.present? and activities_enabled?) || is_bulk_scenario?
      key = changes.keys.first
      add_misc_changes(changes)
      @ticket.system_changes[@rule_id.to_s][key.to_sym].present? ?
            @ticket.system_changes[@rule_id.to_s][key.to_sym] += changes[key.to_sym] :
            @ticket.system_changes[@rule_id.to_s].merge!(changes)
    end

    def fetch_activity_prefix(verb)
      prefix = ACTION_PREFIX
      prefix += (is_bulk_scenario? ? 'bulk_'+verb : verb)
      I18n.t(prefix)
    end

    def priority
      priority = TicketConstants.priority_list[value.to_i]
      add_system_changes({:priority => [nil, value.to_i]})
      params = {:priority => priority}
      "#{fetch_activity_prefix('change')} #{I18n.t('automations.activity.priority', params)}"
    end

    def status
      status = Helpdesk::TicketStatus.status_names_by_key(Account.current)[value.to_i]
      add_system_changes({:status => [nil, value.to_i]})
      params = {:status => status}
      "#{fetch_activity_prefix('change')} #{I18n.t('automations.activity.status', params)}"
    end

    def product_id
      product_name = (value.blank? ? I18n.t('automations.activity.none') : value)
      add_system_changes({:product_id => (value.blank? ? [DONT_CARE, nil] : [nil, value])})
      params = {:product_name => product_name }
      "#{fetch_activity_prefix('set')} #{I18n.t('automations.activity.product', params)}"
    end

    def ticket_type
      add_system_changes({:ticket_type => [nil, value]})
      params = {:ticket_type => value}
      "#{fetch_activity_prefix('change')} #{I18n.t('automations.activity.ticket_type', params)}"
    end

    def group_id(group = nil)
      if group.nil?
        g_id = value.to_i
        group = Account.current.groups.find_by_id(g_id)
      end
      if group.present? || value.blank?
        group_name = (value.blank? ? I18n.t('automations.activity.none') : group.name )
        add_system_changes({:group_id => (value.blank? ? [DONT_CARE, nil] : [nil, group.name])})
        params = {:group_name => group_name}
        "#{fetch_activity_prefix('set')} #{I18n.t('automations.activity.group_success', params)}"
      else
        I18n.t('automations.activity.group_failure')
      end
    end

    def responder_id(responder = nil)
      if responder.nil?
        r_id = value.to_i
        responder = (r_id == EVENT_PERFORMER) ? (doer.agent? ? doer : nil) : Account.current.users.find_by_id(value.to_i)
      end
      
      if responder || value.blank?
        responder_name = (value.blank? ? I18n.t('automations.activity.none') : responder.name )
        add_system_changes({:responder_id => (value.blank? ? ["*", nil] : [nil, responder.id])})
        params = {:agent_name => responder_name}
        "#{fetch_activity_prefix('set')} #{I18n.t('automations.activity.agent_success', params)}"
      else
        I18n.t('automations.activity.agent_failure')
      end
    end

    def add_comment
      verb = fetch_activity_prefix('add')
      if "true".eql?(act_hash[:private])
        add_system_changes({:add_comment => [true]})
        "#{verb} #{I18n.t('automations.activity.private_note')}"
      else
        add_system_changes({:add_comment => [false]})
        "#{verb} #{I18n.t('automations.activity.note')}"
      end
    end

    def add_watcher(watchers = nil)
      watcher_value = value.kind_of?(Array) ? value : value.to_a
      if watchers.nil?
        watchers = Hash.new
        users = Account.current.users.where(:id => watcher_value)
        users.each do |user|
          watchers.merge!({user.id => user.name}) if user.agent?
        end
      end
      add_system_changes({:add_watcher => watchers.keys})
      params = {:watchers => watchers.values.to_sentence}
      "#{fetch_activity_prefix('add')} #{I18n.t('automations.activity.add_watchers', params)}"
    end

    def add_tag(tag_arr = nil)
      tag_array = value.split(',')
      add_system_changes({:add_tag => tag_arr}) if tag_arr.present?
      params = {:tags => tag_array.join(', ')}
      "#{fetch_activity_prefix('assign')} #{I18n.t('automations.activity.add_tags', params)}"
    end

    def add_a_cc
      add_system_changes({:add_a_cc => [value.downcase.strip]})
    end

    def send_email_to_requester
      "#{fetch_activity_prefix('send')} #{I18n.t('automations.activity.email_to_requester')}"
    end

    def send_email_to_group(group = nil)
      verb = fetch_activity_prefix('send')
      if group.nil?        
        "#{verb} #{I18n.t('automations.activity.bulk_email_to_group')}"
      else
        params = {:group_name => group.name}
        "#{verb} #{I18n.t('automations.activity.email_to_group', params)}"
      end
    end

    def send_email_to_agent(agent = nil)
      verb = fetch_activity_prefix('send')
      if agent.nil? 
        "#{verb} #{I18n.t('automations.activity.bulk_email_to_agent')}"
      else
        params = {:agent_name => agent.name}
        "#{verb} #{I18n.t('automations.activity.email_to_agent', params)}"
      end
    end

    def delete_ticket(ticket = nil)
      if ticket.nil? 
        I18n.t('automations.activity.bulk_delete_tickets')
      else
        add_system_changes({:deleted => [false, true]})
        I18n.t('automations.activity.delete_ticket', {:ticket => ticket})
      end
    end

    def mark_as_spam(ticket = nil)
      if ticket.nil? 
        I18n.t('automations.activity.bulk_mark_spam')
      else
        add_system_changes({:spam => [false, true]})
        I18n.t('automations.activity.mark_spam', {:ticket => ticket})
      end
    end

    def custom_fields
      add_system_changes({"#{action_key}".to_sym => (value.blank? ? [DONT_CARE, nil] : [nil, value.to_s])})
      params = {:action => action_key.to_s.humanize().gsub(/ \d+$/,""), :value => value}
      "#{fetch_activity_prefix('set')} #{I18n.t('automations.activity.custom_fields', params)}"
    end

    def set_nested_fields
      add_system_changes({"#{act_hash[:category_name]}".to_sym => (act_hash[:value].blank? ? [DONT_CARE, nil] : [nil, act_hash[:value].to_s])})
      params  = {:action => act_hash[:category_name].to_s.humanize().gsub(/ \d+$/,""), :value => act_hash[:value]}
      message = "#{fetch_activity_prefix('set')} #{I18n.t('automations.activity.custom_fields', params)}"
      act_hash[:nested_rules].each do |field|
        add_system_changes({"#{field[:name]}".to_sym => (field[:value].blank? ? [DONT_CARE, nil] : [nil, field[:value].to_s])})
        params  = {:action => field[:name].to_s.humanize().gsub(/ \d+$/,""), :value => field[:value]}
        message = "#{message}, #{I18n.t('automations.activity.custom_fields', params)}"
      end
      message
    end

    def is_bulk_scenario?
      @bulk_scenario
    end

    def add_misc_changes(changes)
      # Hack to publish activities msg if system rule contains only add watcher/ add a cc action
      if changes.has_key?(:add_watcher) or changes.has_key?(:add_a_cc) or changes.has_key?(:add_comment)
        @ticket.misc_changes = {:misc_changes => [nil, "*"]}
      end
    end
end