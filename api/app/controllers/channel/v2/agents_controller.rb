module Channel::V2
  class AgentsController < ::ApiAgentsController
     def verify_agent_privilege
       @items = { admin: User.current.privilege?(:admin_tasks),
                  allow_agent_to_change_status: api_current_user.toggle_availability? }
     end
  end
end
