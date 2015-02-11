#When an agent is added to a group, we will push him in the round robin redis.
module Helpdesk
  class AddAgentToRoundRobin
      extend Resque::AroundPerform
      @queue = "add_agent_to_round_robin"
     
      def self.perform(args)
          begin
              account = Account.current
              user_id = args[:user_id]
              agent = account.agents.find_by_user_id(user_id)
              group_id = args[:group_id]
              group = account.groups.round_robin_groups.find_by_id(group_id)
              group.add_or_remove_agent(user_id)
          rescue Exception => e
              puts e.inspect, args.inspect
              NewRelic::Agent.notice_error(e, {:args => args})
          end
      end

  end
end
