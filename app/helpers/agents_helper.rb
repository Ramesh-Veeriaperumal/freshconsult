module AgentsHelper
  
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
end