class Groups::SyncAndAssignTickets < BaseWorker
  
  sidekiq_options :queue => :assign_tickets_to_agents,
                  :retry => 2, 
                  :backtrace => true, 
                  :failures => :exhausted

  include Redis::RoundRobinRedis
  include RoundRobinCapping::Methods
  
  def perform(args)
    args.symbolize_keys!
    agent = Account.current.agents.find_by_id(args[:agent_id])
    sync_queues(agent)
    group = agent.groups.find_by_id(args[:group_id]) if args[:group_id].present?
    return unless agent.available
    
    if group.present?
      group.assign_tickets(agent)
    else
      agent.groups.round_robin_groups.capping_enabled_groups.each do |grp|
        grp.assign_tickets(agent)
      end
    end
  end

  def sync_queues(agent)
    action = agent.available ? 'add_agent_to_group_capping' : 'remove_agent_from_group_capping'
      agent.groups.capping_enabled_groups.each do |group|
        group.safe_send(action, agent.user_id)
        
        Rails.logger.debug "RR Success : #{action} : #{agent.user_id} : #{group.id} : #{group.list_capping_range.inspect}
                            #{group.list_unassigned_tickets_in_group.inspect}".squish
      end
  end
end
