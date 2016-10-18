class Groups::AssignTickets < BaseWorker
  
  sidekiq_options :queue => :assign_tickets_to_agents, 
                  :retry => 2, 
                  :backtrace => true, 
                  :failures => :exhausted

  include Redis::RoundRobinRedis
  include RoundRobinCapping::Methods
  
  def perform(args)
    args.symbolize_keys!
    agent = Account.current.agents.find_by_id(args[:agent_id])
    group = agent.groups.find_by_id(args[:group_id]) if args[:group_id].present?

    if group.present?
      group.assign_tickets(agent)
    else
      agent.groups.round_robin_groups.capping_enabled_groups.each do |grp|
        grp.assign_tickets(agent)
      end
    end
  end
end
