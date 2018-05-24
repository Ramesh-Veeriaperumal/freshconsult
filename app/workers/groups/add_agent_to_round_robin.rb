class Groups::AddAgentToRoundRobin < BaseWorker
  
  sidekiq_options queue: :add_agent_to_round_robin, 
                  retry: 2,
                  failures: :exhausted

  def perform(args)
    params = args.deep_symbolize_keys
    account = Account.current
    agent = account.agents.find_by_user_id(params[:user_id])
    group = account.groups.round_robin_groups.find_by_id(params[:group_id])
    group.add_or_remove_agent(params[:user_id]) if agent.available?
  rescue => e
    Rails.logger.error "Error while adding agent via round robin 
      \n#{e.message}\n#{e.backtrace.join("\n\t")}"
    NewRelic::Agent.notice_error(e, {:args => params})
  end

end