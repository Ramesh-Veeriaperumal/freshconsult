module Ember
  class AgentsController < ApiAgentsController
    decorate_views(decorate_object: [:show, :me], decorate_objects: [:index])

    def index
      super
      response.api_meta = { count: @items_count }
    end

    private

      def decorator_options
        super({ agent_groups: Account.current.agent_groups_from_cache })
      end

      def scoper
        if User.current.privilege?(:manage_users)
          current_account.all_agents.preload(user: [:avatar, :user_roles], agent_groups: []).where('users.deleted' => false)
        else
          current_account.agents_details_from_cache
        end
      end
  end
end
