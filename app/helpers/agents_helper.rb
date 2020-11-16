module AgentsHelper
  TOOLBAR_LINK_OPTIONS = {  :remote => true, 
                            :"data-method" => 'get',
                            :"data-type" => 'script',
                            :"data-hide-before" => '.list-page-body',
                            :"data-loading" => 'agents-list',
                            :"data-loading-classes" => 'sloading loading-small'
                          }

  AGENT_SORT_ORDER_COLUMN = [:name, :last_active_at, :created_at]
  AGENT_SORT_ORDER_TYPE = [:ASC, :DESC]
  
  def check_agents_limit
    return content_tag(:div, fetch_upgrade_error_msg('support_agent'), :class => 'errorExplanation') if current_account.reached_agent_limit?

    content_tag(:div, fetch_upgrade_error_msg('field_agent'), class: 'errorExplanation') if current_account.field_service_management_enabled? && current_account.reached_field_agent_limit?
  end
    
  # 1. Agent should not be deleted
  # 2. To edit and agent with manage_account, the current_user must also have manage_account
  def can_edit?(agent)
    current_user.can_edit_agent?(agent)
  end

  def agents_count_tooltip
    if current_account.field_service_management_enabled?
      "data-placement='below' class='agent-list-count bg-dark tooltip' title='#{available_agents} #{t('agent.full_time').downcase.gsub(" ", "-")}, #{available_field_agents} #{t('agent.field_agents').downcase}'"
    else
      "class='agent-list-count bg-dark'"
    end
  end

  def show_buy_more_link
    privilege?(:manage_account) && (current_account.reached_agent_limit? || current_account.reached_field_agent_limit?)
  end
  
  def available_support_agent_licenses
    support_agent_license_available = ((current_account.subscription.agent_limit || 0) - current_account.full_time_support_agents.size)
    current_account.subscription.trial? && support_agent_license_available < 0 ? nil : support_agent_license_available
  end

  def available_collaborator_licenses
    5000 # will be changed in subsequent PR.
  end

  def available_field_agent_licenses
    field_agent_license_available = ((current_account.subscription.field_agent_limit || 0) - current_account.field_agents_count)
    is_initial_state = current_account.subscription.field_agent_limit.nil? && current_account.field_agents_count.zero?
    current_account.subscription.trial? && (is_initial_state || field_agent_license_available < 0) ? nil : field_agent_license_available
  end
  # Should be used only if NOT trial account

  def available_agents
    current_account.subscription.agent_limit - current_account.full_time_support_agents.size
  end
  
  def available_field_agents
    (current_account.subscription.field_agent_limit || 0) - current_account.field_agents_count
  end

  def available_passes
    current_account.day_pass_config.available_passes
  end
  
  def agents_available?
    current_account.subscription.trial? || available_agents > 0
  end
  
  def field_agents_available?
    current_account.subscription.trial? || available_field_agents > 0
  end

  def passes_available?
    available_passes > 0
  end

  def fetch_upgrade_error_msg(agent_type)
    if privilege?(:manage_account)
      agent_type == 'support_agent' ? t('maximum_agents_admin_msg').html_safe : t('maximum_field_agents_admin_msg').html_safe
    else
      agent_type == 'support_agent' ? t('maximum_agents_msg').html_safe : t('maximum_field_agents_msg').html_safe
     end
  end
  
  def agents_exceeded?(agent)
    agent.new_record? ? current_account.reached_agent_limit? : agent.occasional?
  end
 
  def full_time_disabled?(agent)
    (agent.new_record? || agent.occasional?) ? current_account.reached_agent_limit? : false
  end

  def field_agent_disabled?(agent)
    agent.new_record? && current_account.reached_field_agent_limit?
  end

  def is_support_agent?(agent)
    agent.agent_type == AgentType.agent_type_id(Agent::SUPPORT_AGENT)
  end

  def is_field_agent?(agent)
    agent.agent_type == AgentType.agent_type_id(Agent::FIELD_AGENT)
  end
  
  def agent_list_tabs
    state = params.fetch(:state, "active")
    
    available_states = [:active]
    available_states.push(:occasional) if current_account.occasional_agent_enabled?
    available_states.push(:field_agent) if current_account.field_service_management_enabled?
    available_states.push(:deleted)

    available_states.map do |tab|
      content_tag(:li, :class => "#{(state == tab.to_s) ? 'active' : '' }") do
        link_to((t("agent_list.tab.#{tab}") + agent_count_dom(tab)).html_safe,
          "/agents/filter/#{tab}") 
      end.to_s.html_safe
    end.to_s.html_safe
    
  end
  
  def agent_count_dom(state)
    return "" if (:deleted.eql?(state))
    count = agent_count(state)
    "<span class='agent-list-count' data-agent-count='#{count}'> #{count} </span>".html_safe
  end

  def agent_count(state)
    case state
    when :occasional
      agent_type = AgentType.agent_type_id(Agent::SUPPORT_AGENT)
      occasional = true
    when :field_agent
      agent_type = AgentType.agent_type_id(Agent::FIELD_AGENT)
      occasional = false
    when :collaborator
      agent_type = AgentType.agent_type_id(Agent::COLLABORATOR)
      occasional = false
    else
      agent_type = AgentType.agent_type_id(Agent::SUPPORT_AGENT)
      occasional = false
    end
    current_account.agents.where(agent_type: agent_type, occasional: occasional).size
  end
  
  def agent_list_sort
    sort_list = AGENT_SORT_ORDER_COLUMN.map{ |sort| 
      [t("agent_list.sort.#{sort}"), "?order=#{sort}", (@current_agent_order == sort)]
    }
    order_list = AGENT_SORT_ORDER_TYPE.map{ |o_type| 
      [t("agent_list.sort.#{o_type.to_s.downcase}"), "?order_type=#{o_type}", (@current_agent_order_type == o_type)]
    }

    dropdown_menu sort_list.concat([[:divider]]).concat(order_list), TOOLBAR_LINK_OPTIONS
  end

  def current_agent_order
    @current_agent_order ||= set_cookie :order, "name"
  end

  def current_agent_order_type
    @current_agent_order_type ||= set_cookie :order_type, "ASC"
  end

  # Will set a cookie until the browser cache is cleared
  def set_cookie type, default_value
    cookies[type] = (params[type] ? params[type] : ( (!cookies[type].blank?) ? cookies[type] : default_value )).to_sym
  end
  
  def last_active_tooltip(agent)
    if agent.last_active_at
      "class='tooltip' title='#{t('agent.last_seen_at')} #{formated_date(agent.last_active_at, format: :short_day_with_week)}'"
    else
      "class='faded'"
    end
  end 

  def last_active_at(agent)
    if agent.last_active_at
      last_active_in_words(agent)
    else
      t('agent.no_recent_activity')
    end  
  end  

  def last_active_in_words(agent)
    if agent.last_active_at.today?
      t('today')
    elsif agent.last_active_at.to_date == Date.yesterday
      t('yesterday')
    else
      t('agent.days_ago', :days => distance_of_time_in_words_to_now(agent.last_active_at))
    end   
  end   

  def ticket_permission(id)
    ticket_permission_mapper[id]
  end
  
  def ticket_permission_mapper
    {
      :all_tickets => 'agent.global',
      :group_tickets => 'agent.group',
      :assigned_tickets => 'agent.individual'
    } 
  end

  def field_service_management_enabled?
    Account.current.field_service_management_enabled?
  end

  # ITIL Related Methods starts here

  def sidebar_content
  end

  def render_agent_tickets
    output = content_tag(:h3, t('agent_assigned_title').html_safe, :class => "title")
    output << (@recent_unresolved_tickets.empty? ? t('agent_assigned_info') : render(:partial => "tickets", :object => @recent_unresolved_tickets))
    output.html_safe
  end

  def edit?
    action_name == 'edit'
  end
  
  # ITIL Related Methods ends here

  def edit?
    action_name == 'edit'
  end

  alias available_support_agents available_agents
end
