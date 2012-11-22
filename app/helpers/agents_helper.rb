module AgentsHelper
  
  def check_agents_limit
    content_tag(:div, fetch_upgrade_error_msg,:class => "errorExplanation") if current_account.reached_agent_limit?
  end
  

  def can_destroy?(agent)
     (agent.user != current_user) && (!agent.user.account_admin?)
  end

  def fetch_upgrade_error_msg
    if permission?(:manage_account)
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
 
 def authorized_to_manage_agents
       access_denied unless  manage_agents?
 end

 def authorized_to_view_agents
      access_denied unless can_show?
 end

 def manage_agents?
     permission?(:manage_users)
  end

  def can_show?
    (current_user && current_user.can_view_all_tickets?)
  end  

end
