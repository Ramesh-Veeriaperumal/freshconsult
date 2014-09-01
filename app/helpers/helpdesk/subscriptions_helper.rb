module Helpdesk::SubscriptionsHelper

  def unsubscribed_agent_list
    agent_list_hash = @ticket.unsubscribed_agents
    agent_list = []
    
    if agent_list_hash.reject! { |k| k.user_id == current_user.id }
      agent_list.push([current_user.id, t("helpdesk.tickets.add_watcher.me") ])
    end
    
    agent_list.concat(agent_list_hash.collect { |au| [au.user.id, au.user.name] })
    agent_list
  end
end