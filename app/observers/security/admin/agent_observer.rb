class Security::Admin::AgentObserver < ActiveRecord::Observer

  observe Agent

  include SecurityNotification
  
  def after_commit(agent)
    if agent.safe_send(:transaction_include_action?, :create)
      commit_on_create(agent)
    elsif agent.safe_send(:transaction_include_action?, :destroy)
      commit_on_destroy(agent)
    end
    true
  end
  
  private

  def commit_on_create(agent)
    return if skip_notification?(agent)    
    subject = { key: 'mailer_notifier_subject.agent_added',
                locals: {
                  account_name: agent.account.name
                }
              }
    roles_name = agent.user.roles.map(&:name)
    notify_admins(agent.user, subject, "agent_create", roles_name.to_a)
  end

  def commit_on_destroy(agent)
    subject = { 
      key: 'mailer_notifier_subject.agent_deleted',
      locals: {
        agent_name: agent.user.name,
        account_name: agent.account.name
      }
    }
    notify_admins(agent.user, subject, "agent_delete", [])
  end

  def skip_notification?(agent)
    return !Account.current.verified? || ( agent.account.contact_info[:email] == agent.user.email ? true : false )
  end

end
