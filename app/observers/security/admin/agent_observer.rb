class Security::Admin::AgentObserver < ActiveRecord::Observer

  observe Agent

  include SecurityNotification
  
  def after_commit(agent)
    if agent.send(:transaction_include_action?, :create)
      commit_on_create(agent)
    elsif agent.send(:transaction_include_action?, :destroy)
      commit_on_destroy(agent)
    end
    true
  end
  
  private

  def commit_on_create(agent)
    return if skip_notification?(agent)
    subject = "#{agent.account.name}: A new agent was added in your helpdesk"
    roles_name = agent.user.roles.map(&:name)
    notify_admins(agent.user, subject, "agent_create", roles_name.to_a)
  end

  def commit_on_destroy(agent)
    subject = "#{agent.account.name}: #{agent.user.name} was deleted"
    notify_admins(agent.user, subject, "agent_delete", [])
  end

  def skip_notification?(agent)
    return agent.account.contact_info[:email] == agent.user.email ? true : false
  end

end
