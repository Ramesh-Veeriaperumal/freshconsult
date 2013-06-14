module AgentsHelper
  TOOLBAR_LINK_OPTIONS = {  "data-remote" => true, 
                            "data-method" => :get,
                            "data-response-type" => "script",
                            "data-loading-box" => "#agents-list" }

  
  def check_agents_limit
    content_tag(:div, fetch_upgrade_error_msg,:class => "errorExplanation") if current_account.reached_agent_limit?
  end
    
  # 1. Agent should not be deleted
  # 2. To edit and agent with manage_account, the current_user must also have manage_account
  def can_edit?(agent)
    !(agent.user.deleted? || 
      (agent.user.privilege?(:manage_account) && !current_user.privilege?(:manage_account)))
  end
  
  # Should be used only if NOT trial account
  def available_agents
    current_account.subscription.agent_limit - current_account.full_time_agents.size
  end
  
  def available_passes
    current_account.day_pass_config.available_passes
  end
  
  def agents_available?
    current_account.subscription.trial? || available_agents > 0
  end
  
  def passes_available?
    available_passes > 0
  end

  def fetch_upgrade_error_msg
    if privilege?(:manage_account)
      t('maximum_agents_admin_msg')
    else
      t('maximum_agents_msg')
     end
  end
  
  def agents_exceeded?(agent)
   if agent.new_record?
     current_account.reached_agent_limit?
   else 
     agent.occasional?
   end
 end 
 
  def full_time_disabled?(agent)
   if agent.new_record?
     current_account.reached_agent_limit?
   elsif agent.occasional?
     current_account.reached_agent_limit?
   else
     false
   end
 end
  
  def agent_list_tabs
    state = params.fetch(:state, "active")
    
    [:active, :occasional, :deleted].map do |tab|  
      content_tag(:li, :class => "#{(state == tab.to_s) ? 'active' : '' }") do
        link_to(t("agent_list.tab.#{tab}") + agent_count(tab),
          "/agents/filter/#{tab}") 
      end
    end
    
  end
  
  def agent_count(state)
    unless(:deleted.eql?(state))
      scoper = :occasional.eql?(state) ? "occasional_agents" : "full_time_agents"
      "<span class='agent-list-count'>" +
        current_account.all_agents.send(scoper).size.to_s +
      "</span>"
    else
      ""
    end
  end
  
  def agent_list_sort
    sort_list = [:name, :last_login_at, :created_at].map{ |sort| 
      [t("agent_list.sort.#{sort}"), "?order=#{sort}", (@current_agent_order == sort)]
    }
    order_list = [:ASC, :DESC].map{ |o_type| 
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
  
  def last_login_tooltip(agent)
    if agent.user.last_login_at
      "class='tooltip' title='#{formated_date(agent.user.last_login_at)}'"
    end
  end

end
