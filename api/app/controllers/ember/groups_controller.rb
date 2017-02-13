module Ember
  class GroupsController < ::ApiGroupsController
    decorate_views
    def index
      super
      response.api_meta = { count: @items_count }
    end

    private

      def decorator_options
        super({ agent_groups: Account.current.agent_groups_from_cache })
      end
  end
end
