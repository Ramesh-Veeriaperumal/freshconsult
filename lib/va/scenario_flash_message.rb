class Va::ScenarioFlashMessage

  EVENT_PERFORMER = -2
  ACTION_PREFIX = 'automations.activity.'
  attr_accessor :action_key, :act_hash, :value, :doer, :bulk_scenario

  def initialize(act_hash, doer, bulk_scenario = false)
    @act_hash = act_hash
    @action_key = act_hash[:name]
    @value = act_hash[:value]
    @doer = doer
    @bulk_scenario = bulk_scenario
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
    def fetch_activity_prefix(verb)
      prefix = ACTION_PREFIX
      prefix += (is_bulk_scenario? ? 'bulk_'+verb : verb)
      I18n.t(prefix)
    end

    def priority
      priority = TicketConstants.priority_list[value.to_i]
      params = {:priority => priority}
      "#{fetch_activity_prefix('change')} #{I18n.t('automations.activity.priority', params)}"
    end

    def status
      status = Helpdesk::TicketStatus.status_names_by_key(Account.current)[value.to_i]
      params = {:status => status}
      "#{fetch_activity_prefix('change')} #{I18n.t('automations.activity.status', params)}"
    end

    def product_id
      product_name = (value.blank? ? I18n.t('automations.activity.none') : value)
      params = {:product_name => product_name }
      "#{fetch_activity_prefix('set')} #{I18n.t('automations.activity.product', params)}"
    end

    def ticket_type
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
        params = {:agent_name => responder_name}
        "#{fetch_activity_prefix('set')} #{I18n.t('automations.activity.agent_success', params)}"
      else
        I18n.t('automations.activity.agent_failure')
      end
    end

    def add_comment
      verb = fetch_activity_prefix('add')
      if "true".eql?(act_hash[:private])
        "#{verb} #{I18n.t('automations.activity.private_note')}"
      else
        "#{verb} #{I18n.t('automations.activity.note')}"
      end
    end

    def add_watcher(watchers = nil)
      if watchers.nil?
        watchers = Array.new
        watcher_value = value.kind_of?(Array) ? value : value.to_a
        watcher_value.each do |watcher_id|
          user = Account.current.users.find_by_id(watcher_id)
          if user && user.agent?
            watchers.push user.name
          end
        end
      end
      params = {:watchers => watchers.to_sentence}
      "#{fetch_activity_prefix('add')} #{I18n.t('automations.activity.add_watchers', params)}"
    end

    def add_tag
      params = {:tags => value.split(',').join(', ')}
      "#{fetch_activity_prefix('assign')} #{I18n.t('automations.activity.add_tags', params)}"
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
        I18n.t('automations.activity.delete_ticket', {:ticket => ticket})
      end
    end

    def mark_as_spam(ticket = nil)
      if ticket.nil? 
        I18n.t('automations.activity.bulk_mark_spam')
      else
        I18n.t('automations.activity.mark_spam', {:ticket => ticket})
      end
    end

    def custom_fields
      params = {:action => action_key.to_s.humanize().gsub(/ \d+$/,""), :value => value}
      "#{fetch_activity_prefix('set')} #{I18n.t('automations.activity.custom_fields', params)}"
    end

    def set_nested_fields
      params  = {:action => act_hash[:category_name].to_s.humanize().gsub(/ \d+$/,""), :value => act_hash[:value]}
      message = "#{fetch_activity_prefix('set')} #{I18n.t('automations.activity.custom_fields', params)}"
      act_hash[:nested_rules].each do |field|
        params  = {:action => field[:name].to_s.humanize().gsub(/ \d+$/,""), :value => field[:value]}
        message = "#{message}, #{I18n.t('automations.activity.custom_fields', params)}"
      end
      message
    end

    def is_bulk_scenario?
      @bulk_scenario
    end

end