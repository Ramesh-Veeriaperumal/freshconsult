class Groups::AddAgentToRoundRobin < BaseWorker
  
  sidekiq_options queue: :add_agent_to_round_robin, 
                  retry: 2,
                  failures: :exhausted

  def perform(args)
    args.symbolize_keys!
    account = Account.current
    agent = account.agents.find_by_user_id(args[:user_id])
    group = account.groups.round_robin_groups.find_by_id(args[:group_id])
    group.add_or_remove_agent(args[:user_id]) if agent.available?
  rescue => e
    Rails.logger.error "Error while adding agent via round robin 
      \n#{e.message}\n#{e.backtrace.join("\n\t")}"
    NewRelic::Agent.notice_error(e, {:args => args})
  end

end