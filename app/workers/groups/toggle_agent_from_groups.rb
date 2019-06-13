class Groups::ToggleAgentFromGroups < BaseWorker

  sidekiq_options queue:  :toggle_agent_from_all_roundrobin_groups,
                  retry: 2,
                  failures:  :exhausted

  def perform(args)
    account = Account.current
    params  = args.symbolize_keys
    user_id = params[:user_id]
    agent   = account.agents.where(:user_id => user_id).first
    return if agent.nil?
    agent.agent_groups.preload(:group).each do |agent_group|
      group = agent_group.group
      next if group.nil? || !group.round_robin_enabled?
      group.add_or_remove_agent(user_id, agent.available?)
    end
  rescue Exception => e
    Rails.logger.error e.inspect, params.inspect
    NewRelic::Agent.notice_error(e, {:args => params})
  end
end