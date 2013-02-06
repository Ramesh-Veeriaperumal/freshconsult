module AgentsHelper
  TOOLBAR_LINK_OPTIONS = {  "data-remote" => true, 
                            "data-method" => :get,
                            "data-response-type" => "script",
                            "data-loading-box" => "#agents-list" }

  
  def check_agents_limit
    content_tag(:div, fetch_upgrade_error_msg,:class => "errorExplanation") if current_account.reached_agent_limit?
  end
  
  def can_destroy?(agent)
     (agent.user != current_user) && (!agent.user.account_admin?)
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

  def can_reset_password?(agent)
   agent.user.active? and (current_user != agent.user)
  end
  
  def agent_list_tabs
    state = params.fetch(:state, "active")
    [:active, :occasional, :deleted].map{ |tab|  
      content_tag :li, link_to(t("agent_list.tab.#{tab}"), "/agents/filter/#{tab}"), 
        :class => "#{(state == tab.to_s) ? 'active' : '' }"
    }
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

end
