#When an agent turns off his availability from round robin or logsout
#We will remove him from all round robin groups. This worker does that
module Helpdesk
  class ToggleAgentFromGroups
      extend Resque::AroundPerform
      @queue = "toggle_agent_from_all_roundrobin_groups"
     
      def self.perform(args)
          begin
              account = Account.current
              user_id = args[:user_id]
              agent = account.agents.find_by_user_id(user_id)
              groups = account.groups.round_robin_groups
              groups.each do |group|
                group.add_or_remove_agent(user_id,agent.available?)
              end
              
          rescue Exception => e
              puts e.inspect, args.inspect
              NewRelic::Agent.notice_error(e, {:args => args})
          end
      end

  end
end