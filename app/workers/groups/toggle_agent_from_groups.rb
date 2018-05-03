class Groups::ToggleAgentFromGroups < BaseWorker

  sidekiq_options :queue => :toggle_agent_from_all_roundrobin_groups,
                  :retry => 2,
                  :backtrace => true,
                  :failures => :exhausted

  def perform(args)
    account = Account.current
    user_id = args[:user_id]
    agent = account.agents.where(:user_id => user_id).first
    return if agent.nil?
    agent.agent_groups.each do |agent_group|
      group = agent_group.group
      group.add_or_remove_agent(user_id,agent.available?) if group.round_robin_enabled?
    end
  rescue Exception => e
    puts e.inspect, args.inspect
    NewRelic::Agent.notice_error(e, {:args => args})
  end
end